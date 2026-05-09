# ADR 0006: Generative UI via LLM Tool Use and Turbo Streams

## Status
Accepted

## Context

RepoTalk's RAG pipeline retrieves relevant code chunks and passes them to an LLM to answer developer questions. The naive approach is to render the LLM's response as a plain text chat bubble. This is a missed opportunity: technical documentation answers naturally decompose into structured artifacts — code snippets, file references, comparison tables, step-by-step guides — each of which benefits from dedicated UI treatment (syntax highlighting, copy buttons, line anchors, collapsible sections).

**Generative UI** is the pattern where the LLM itself decides which UI components to render. Rather than returning Markdown text, the model uses Tool Use (function calling) to invoke component-rendering functions. The backend intercepts those tool calls, renders the matching view partial, and streams the resulting HTML to the client. The UI becomes a direct product of the model's reasoning about the query type.

The key constraint is that our frontend is Hotwire (Turbo + Stimulus), not a React/Next.js SPA. Vercel's `streamUI` and React Server Components are not applicable. We need an equivalent pattern native to the Rails stack.

## Decision

We will implement Generative UI using **LLM Tool Use + Turbo Streams over SSE**, following this flow:

```
User Query
    ↓
ChatController (Rails, ActionController::Live)
    ├── 1. Embed query → pgvector k-NN search (pre-filtered by repository_id)
    ├── 2. Build prompt: system prompt + retrieved chunks + user query
    └── 3. Call LLM via Langchainrb with the component tool definitions
             ↓
         LLM returns tool_use blocks (may be multiple, sequential or parallel):
           { name: "render_code_block",      input: { code:, language:, explanation: } }
           { name: "render_file_reference",  input: { path:, lines:, excerpt: } }
           { name: "render_step_guide",      input: { title:, steps: [] } }
           { name: "render_comparison_table",input: { headers:, rows: [] } }
           { name: "render_plain_answer",    input: { content: } }
             ↓
         Backend processes each tool call in order:
           → Renders Rails partial: render_to_string("chat/components/_#{name}", locals: input)
           → Streams via SSE: response.stream.write(turbo_stream.append("chat-messages", html))
             ↓
         Browser receives incremental Turbo Stream updates
             ↓
         Stimulus controllers handle interactivity per component
```

### Component Vocabulary

| Tool name | Rendered partial | Use case |
| :--- | :--- | :--- |
| `render_code_block` | `_code_block.html.erb` | Code snippets, function bodies, config examples |
| `render_file_reference` | `_file_reference.html.erb` | Pointing to a specific file + line range in the repo |
| `render_comparison_table` | `_comparison_table.html.erb` | "X vs Y", option trade-offs |
| `render_step_guide` | `_step_guide.html.erb` | How-to / setup instructions |
| `render_plain_answer` | `_plain_answer.html.erb` | Simple factual answers, follow-up clarifications |

The LLM is given a system prompt that instructs it to always respond via one or more of these tools rather than with raw text. For a single query, it may call several tools sequentially (e.g., a `render_plain_answer` followed by a `render_code_block`).

### Streaming via `ActionController::Live`

The controller includes `ActionController::Live` and writes SSE-formatted Turbo Stream events directly to `response.stream`. Each rendered component partial is appended to the `#chat-messages` Turbo Frame as soon as the LLM emits its tool call, giving the user a progressive rendering experience without waiting for the full response.

```ruby
# Conceptual skeleton — not final code
response.headers["Content-Type"] = "text/event-stream"
llm_response.tool_calls.each do |call|
  html = render_to_string("chat/components/_#{call.name}", locals: call.input.symbolize_keys)
  response.stream.write("data: #{turbo_stream.append('chat-messages', html)}\n\n")
end
response.stream.close
```

### Stimulus Controllers

Each component partial includes a `data-controller` attribute wiring it to a lightweight Stimulus controller that handles client-side behavior:

- `code-block` controller: syntax highlighting (via highlight.js or Prism), copy-to-clipboard button.
- `file-reference` controller: opens the file at the referenced line in a modal or expandable drawer.
- `step-guide` controller: checkable steps, progress tracking within the session.
- `comparison-table` controller: sortable columns.

## Rationale

**Why Tool Use instead of structured JSON parsing?**
Tool Use is the canonical, model-native way to produce structured output. It avoids brittle regex/JSON parsing of free-text responses and gives the model a clear vocabulary to select from. Anthropic's Claude and OpenAI's models both support it natively via Langchainrb.

**Why SSE instead of Action Cable (WebSockets)?**
SSE (Server-Sent Events) is unidirectional and stateless — perfectly matched to the AI streaming pattern where only the server pushes incremental updates. It requires no persistent WebSocket infrastructure and works over standard HTTP/2. Action Cable would add connection overhead with no benefit for this one-way flow.

**Why Hotwire/Turbo instead of adopting a JS framework for Generative UI?**
The rest of the stack is already Rails + Hotwire. Introducing React solely for Generative UI would create a bifurcated frontend. Turbo Streams are expressive enough: each tool call maps cleanly to a `turbo_stream.append` targeting a named frame. The result is the same progressive component rendering without a JavaScript build pipeline.

**Why a fixed component vocabulary rather than fully open-ended generation?**
Fully open-ended generation (e.g., the model outputs arbitrary HTML) creates XSS risk and unpredictable UX. A predefined vocabulary of 5 components covers 95% of documentation query types while keeping the surface area auditable and the partials testable.

## Consequences

**Positive:**
- Each query produces a structured, visually rich response tailored to the answer type rather than a wall of Markdown text.
- Components are standard Rails partials — they are independently testable and easy to restyle.
- Progressive streaming gives immediate visual feedback on slow LLM responses.
- The component vocabulary is self-documenting: reading the tool definitions explains every possible UI state.

**Negative:**
- Tool Use adds latency overhead compared to streaming raw text, as the model must complete a tool call before the backend can render the partial.
- The system prompt must be carefully engineered to prevent the model from falling back to raw text when it cannot decide on a component — requires a `render_plain_answer` fallback tool.
- SSE connections held open during LLM inference consume a Rails thread/process for the duration of the request. Puma's thread pool or an async adapter (Falcon) must be sized accordingly.

**Neutral:**
- The `ActionController::Live` streaming pattern is incompatible with some middleware (e.g., certain rack-based response buffering). The middleware stack must be audited.
- highlight.js or Prism must be included in the asset pipeline for the `code-block` Stimulus controller.
