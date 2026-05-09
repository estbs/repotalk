require "baran"

class IngestionService
  Error = Class.new(StandardError)

  CHUNK_SIZE    = 1000
  CHUNK_OVERLAP = 100

  PROCESSABLE_EXTENSIONS = %w[
    .rb .py .js .ts .jsx .tsx .go .rs .java .kt .swift
    .md .txt .yml .yaml .toml .json .sh .sql .html .css
    .erb .graphql .proto .ex .exs .clj .scala .php
  ].freeze

  IGNORED_DIRS = %w[.git node_modules .bundle vendor/bundle tmp log].freeze

  def initialize(repository)
    @repository = repository
    @llm = Langchain::LLM::Ollama.new(
      url: ENV.fetch("OLLAMA_URL", "http://localhost:11434"),
      default_options: { embedding_model: "nomic-embed-text" }
    )
  end

  def call
    @repository.ingesting!
    # Use a direct relation instead of the association so destroy_all doesn't
    # mark the association cache as loaded-empty, which would hide new chunks
    # created later via DocumentChunk.create!.
    DocumentChunk.where(repository: @repository).destroy_all

    with_source_files do |files|
      chunks = split_files(files)
      embed_and_persist(chunks)
    end

    @repository.update!(status: "ready", ingested_at: Time.current)
  rescue Error
    @repository.failed!
    raise
  rescue => e
    @repository.failed!
    raise Error, "Ingestion failed: #{e.message}"
  end

  private

  def with_source_files(&block)
    if local_path?
      block.call(collect_files(@repository.url))
    else
      Dir.mktmpdir("repotalk-") do |tmpdir|
        clone_repository(tmpdir)
        block.call(collect_files(tmpdir))
      end
    end
  end

  def local_path?
    @repository.url.match?(%r{\A[./]})
  end

  def clone_repository(dest)
    unless system("git", "clone", "--depth=1", "--quiet", @repository.url, dest)
      raise Error, "Failed to clone #{@repository.url}"
    end
  end

  def collect_files(base_path)
    Dir.glob(File.join(base_path, "**", "*"))
       .select { |path| File.file?(path) && processable?(path, base_path) }
       .filter_map do |path|
         content = File.read(path, encoding: "utf-8", invalid: :replace, undef: :replace)
         next if content.strip.empty?
         { relative_path: path.delete_prefix("#{base_path}/"), content: content }
       rescue => _e
         nil
       end
  end

  def processable?(path, base_path)
    relative = path.delete_prefix("#{base_path}/")
    return false if IGNORED_DIRS.any? { |dir| relative.start_with?("#{dir}/") }
    PROCESSABLE_EXTENSIONS.include?(File.extname(path).downcase)
  end

  def split_files(files)
    splitter = ::Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: CHUNK_SIZE,
      chunk_overlap: CHUNK_OVERLAP
    )

    files.flat_map do |file|
      raw_chunks = splitter.chunks(file[:content]).reject { |c| c[:text].strip.empty? }
      annotate_lines(raw_chunks, file[:content], file[:relative_path])
    end
  end

  # Maps each Baran chunk back to line numbers in the original file.
  # search_from advances past each chunk (minus overlap) so repeated substrings
  # resolve to the correct occurrence.
  def annotate_lines(raw_chunks, text, file_path)
    search_from = 0

    raw_chunks.each_with_index.map do |raw, index|
      content    = raw[:text]
      start_char = text.index(content, search_from) || search_from
      end_char   = start_char + content.length
      search_from = [start_char + content.length - CHUNK_OVERLAP, start_char + 1].max

      {
        content:     content,
        file_path:   file_path,
        chunk_index: index,
        start_line:  text[0...start_char].count("\n") + 1,
        end_line:    text[0...end_char].count("\n") + 1
      }
    end
  end

  def embed_and_persist(chunks)
    return if chunks.empty?

    DocumentChunk.transaction do
      chunks.each do |chunk_data|
        embedding = @llm.embed(text: chunk_data[:content]).embeddings.first
        DocumentChunk.create!(chunk_data.merge(repository: @repository, embedding: embedding))
      end
    end
  end
end
