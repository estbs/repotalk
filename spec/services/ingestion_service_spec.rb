require "rails_helper"

RSpec.describe IngestionService do
  let(:fake_embedding) { Array.new(1536, 0.1) }

  # Use a real local directory so the full file-collection path runs
  # without a network call. Only the OpenAI embed call is stubbed.
  let(:source_dir) do
    Dir.mktmpdir("repotalk-test-").tap do |dir|
      File.write("#{dir}/app.rb",    "# frozen_string_literal: true\n\nmodule App\n  VERSION = \"1.0\"\nend\n")
      File.write("#{dir}/README.md", "# TestRepo\n\nThis is a test repository.\n")
    end
  end

  let(:repository) { create(:repository, url: source_dir) }
  let(:service)    { described_class.new(repository) }

  after { FileUtils.rm_rf(source_dir) }

  before do
    @llm_double = instance_double(Langchain::LLM::OpenAI)
    allow(Langchain::LLM::OpenAI).to receive(:new).and_return(@llm_double)

    allow(@llm_double).to receive(:embed) do |text:|
      texts    = Array(text)
      response = instance_double(Langchain::LLM::OpenAIResponse)
      allow(response).to receive(:embeddings).and_return(texts.map { fake_embedding })
      response
    end
  end

  describe "#call" do
    subject(:call) { service.call }

    it "transitions the repository to ready" do
      expect { call }.to change { repository.reload.status }.from("pending").to("ready")
    end

    it "records ingested_at" do
      expect { call }.to change { repository.reload.ingested_at }.from(nil)
    end

    it "creates at least one DocumentChunk per source file" do
      call
      paths = repository.document_chunks.pluck(:file_path).uniq
      expect(paths).to include("app.rb", "README.md")
    end

    it "assigns all chunks to the repository" do
      call
      expect(repository.document_chunks.pluck(:repository_id).uniq).to eq([repository.id])
    end

    it "stores an embedding on every chunk" do
      call
      expect(repository.document_chunks.map(&:embedding)).to all(eq(fake_embedding))
    end

    it "records start_line and end_line for each chunk" do
      call
      repository.document_chunks.each do |chunk|
        expect(chunk.start_line).to be >= 1
        expect(chunk.end_line).to be >= chunk.start_line
      end
    end

    it "destroys stale chunks before re-ingesting" do
      stale = create(:document_chunk, repository: repository)
      call
      expect(DocumentChunk.exists?(stale.id)).to be false
    end

    context "when a file produces multiple chunks" do
      before do
        # 100 lines × ~24 chars each ≈ 2400 chars — enough to exceed CHUNK_SIZE (1000)
        File.write("#{source_dir}/large.rb", "# a line of code here\n" * 100)
      end

      it "produces more than one chunk for that file" do
        call
        expect(repository.document_chunks.where(file_path: "large.rb").count).to be > 1
      end

      it "assigns sequential chunk_index values starting at 0" do
        call
        indices = repository.document_chunks
                             .where(file_path: "large.rb")
                             .order(:chunk_index)
                             .pluck(:chunk_index)
        expect(indices).to eq((0...indices.length).to_a)
      end
    end

    context "when a non-processable file is present" do
      before { File.write("#{source_dir}/image.png", "\x89PNG\r\n") }

      it "ignores the file and still completes" do
        expect { call }.not_to raise_error
        paths = repository.document_chunks.pluck(:file_path)
        expect(paths).not_to include("image.png")
      end
    end

    context "when the LLM raises an error" do
      before do
        allow(@llm_double).to receive(:embed).and_raise(StandardError, "OpenAI timeout")
      end

      it "transitions the repository to failed" do
        expect { call }.to raise_error(IngestionService::Error)
        expect(repository.reload.status).to eq("failed")
      end

      it "wraps the original error as IngestionService::Error" do
        expect { call }.to raise_error(IngestionService::Error, /Ingestion failed: OpenAI timeout/)
      end
    end
  end
end
