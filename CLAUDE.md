# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

RepoTalk is a RAG (Retrieval-Augmented Generation) application that lets developers query technical documentation conversationally. It is a portfolio "Anchor" project demonstrating AI integration in a production-grade Rails stack.

## Tech Stack

| Layer | Technology |
| :--- | :--- |
| Backend | Ruby on Rails 8 |
| Vector storage | PostgreSQL + pgvector (`neighbor` gem or langchainrb) |
| AI orchestration | Langchainrb |
| Embedding model | OpenAI `text-embedding-3-small` (1536 dimensions) |
| Frontend | Hotwire (Turbo + Stimulus) — no SPA |
| Background jobs | Solid Queue |
| Testing | RSpec |

## RAG Architecture

The core pipeline (see ADR 0003) works in two phases:

**Ingestion** (background job via Solid Queue):
1. Files from a repository are split using recursive character splitting (1000-char chunks, 100-char overlap).
2. Each chunk is embedded via `text-embedding-3-small`.
3. Chunks are stored in PostgreSQL with pgvector, tagged with `repository_id`, file path, and line numbers.

**Query**:
1. The user's question is embedded with the same model.
2. pgvector performs a k-NN similarity search pre-filtered by `repository_id`.
3. Retrieved chunks are passed as context to the LLM via langchainrb.

The `repository_id` filter on every vector search is intentional — it scopes answers to a specific repo and keeps queries fast.

## Generative UI

RepoTalk does not render AI responses as plain text. Instead, the LLM uses **Tool Use (function calling)** to invoke one or more UI component functions. The backend renders the matching Rails partial and streams it to the browser via **Turbo Streams over SSE** (`ActionController::Live`). The LLM decides which component fits the answer; the backend renders it.

**Component vocabulary** (5 tools the LLM can call):

| Tool | Partial | When the LLM uses it |
| :--- | :--- | :--- |
| `render_code_block` | `_code_block.html.erb` | Code snippets, function bodies |
| `render_file_reference` | `_file_reference.html.erb` | Pointing to a specific file + line range |
| `render_comparison_table` | `_comparison_table.html.erb` | Trade-off / X vs Y answers |
| `render_step_guide` | `_step_guide.html.erb` | How-to / setup instructions |
| `render_plain_answer` | `_plain_answer.html.erb` | Simple factual answers (fallback) |

A single query may produce multiple sequential tool calls (e.g., `render_plain_answer` then `render_code_block`). Each is streamed independently as it arrives, so the user sees components appear progressively.

Each partial includes a `data-controller` attribute wiring it to a Stimulus controller that handles client-side behavior: syntax highlighting + copy button (`code-block`), expandable file drawer (`file-reference`), checkable steps (`step-guide`), sortable columns (`comparison-table`).

**Why not React/`streamUI`?** SSE + Turbo Streams provide the same progressive component streaming without a JS build pipeline. Each tool call maps to a `turbo_stream.append` on the `#chat-messages` frame. SSE is preferred over Action Cable because this is a one-way server push — no WebSocket overhead needed.

See ADR 0006 for the full rationale, including the XSS-safe reasoning behind a fixed component vocabulary and the Puma thread-pool implications of held-open SSE connections.

## Key Architectural Decisions

All ADRs live in `doc/architecture/adr/`. The decisions with the most design impact:

- **pgvector over dedicated vector DBs** (ADR 0002): All data stays in one ACID-compliant PostgreSQL instance. Avoids a second database cluster. Trade-off: the PostgreSQL instance bears the HNSW/IVFFlat index build cost.
- **Recursive character splitting** (ADR 0003): Respects paragraph/function boundaries better than fixed-length splitting. 10% overlap guards against context loss at chunk boundaries.
- **Generative UI via Tool Use + Turbo Streams** (ADR 0006): LLM selects and populates UI components via function calling; backend renders Rails partials and streams them over SSE.

## Testing

RSpec is the test framework. Coverage is focused on data retrieval logic (the RAG pipeline), not generic CRUD.
