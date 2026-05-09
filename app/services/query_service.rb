class QueryService
  CONTEXT_CHUNKS = 5
  MODEL          = "gpt-4o-mini"

  TOOLS = [
    {
      type: "function",
      function: {
        name: "render_plain_answer",
        description: "Render a plain text answer. Use for general explanations and summaries.",
        parameters: {
          type: "object",
          properties: {
            content: { type: "string", description: "The answer text (markdown supported)." }
          },
          required: ["content"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "render_code_block",
        description: "Render a syntax-highlighted code block. Use when showing code examples or snippets.",
        parameters: {
          type: "object",
          properties: {
            language:    { type: "string", description: "Programming language for syntax highlighting." },
            code:        { type: "string", description: "The code to display." },
            explanation: { type: "string", description: "Brief explanation of what the code does." }
          },
          required: ["language", "code"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "render_file_reference",
        description: "Point to a specific file or line range in the repository.",
        parameters: {
          type: "object",
          properties: {
            file_path:   { type: "string", description: "Path to the file relative to repo root." },
            start_line:  { type: "integer", description: "Starting line number." },
            end_line:    { type: "integer", description: "Ending line number." },
            explanation: { type: "string", description: "Why this file or section is relevant." }
          },
          required: ["file_path", "explanation"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "render_comparison_table",
        description: "Render a comparison table. Use when comparing options, attributes, or patterns.",
        parameters: {
          type: "object",
          properties: {
            headers: {
              type: "array",
              items: { type: "string" },
              description: "Column headers."
            },
            rows: {
              type: "array",
              items: { type: "array", items: { type: "string" } },
              description: "Table rows, each an array of cell values."
            }
          },
          required: ["headers", "rows"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "render_step_guide",
        description: "Render a numbered step-by-step guide. Use when explaining a process or setup.",
        parameters: {
          type: "object",
          properties: {
            title: { type: "string", description: "Title of the guide." },
            steps: {
              type: "array",
              items: { type: "string" },
              description: "Ordered steps."
            }
          },
          required: ["title", "steps"]
        }
      }
    }
  ].freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an expert code repository assistant. Answer questions about the repository using the provided source code context.

    You MUST respond by calling one or more of the provided tools to render structured UI components.
    Never include any plain text outside of tool calls.

    Guidelines:
    - Use render_plain_answer for general explanations and summaries.
    - Use render_code_block when showing code examples or snippets.
    - Use render_file_reference when pointing to specific files or line ranges.
    - Use render_comparison_table when comparing options, patterns, or attributes.
    - Use render_step_guide when explaining a process or setup steps.
    - Combine multiple tool calls for complete answers (e.g., explanation + code block + file reference).
  PROMPT

  def initialize(repository, question)
    @repository = repository
    @question   = question
    @llm = Langchain::LLM::OpenAI.new(
      api_key: ENV.fetch("OPENAI_API_KEY"),
      default_options: { chat_completion_model_name: MODEL }
    )
  end

  def call
    query_embedding = @llm.embed(text: @question).embeddings.first
    chunks = DocumentChunk.search(query_embedding, repository: @repository, limit: CONTEXT_CHUNKS)

    context = chunks.map do |c|
      "File: #{c.file_path} (lines #{c.start_line}-#{c.end_line})\n#{c.content}"
    end.join("\n\n---\n\n")

    messages = [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user",   content: "Context:\n#{context}\n\nQuestion: #{@question}" }
    ]

    response = @llm.chat(
      messages:    messages,
      tools:       TOOLS,
      tool_choice: "required"
    )

    parse_tool_calls(response)
  end

  private

  def parse_tool_calls(response)
    (response.tool_calls || []).map do |tc|
      {
        component: tc.dig("function", "name"),
        input:     JSON.parse(tc.dig("function", "arguments"))
      }
    end
  end
end
