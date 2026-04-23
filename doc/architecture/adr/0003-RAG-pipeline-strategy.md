# ADR 0003: RAG Strategy and Chunking Logic
## Status
Accepted

## Context
Technical documentation and source code vary significantly in length and structure. To provide accurate answers, we cannot send an entire repository to a Language Model (LLM) due to token limits and "lost in the middle" phenomena. We need a strategy to:

Break down files into manageable pieces (Chunking).

Convert those pieces into searchable vectors (Embedding).

Retrieve the most relevant pieces for a user's query (Retrieval).

## Decision
We will implement a Recursive Character Splitting strategy with a hybrid metadata approach.

## Technical Details:

**Chunk Size:** 1000 characters.

**Chunk Overlap:** 100 characters (to maintain context between segments).

**Embedding Model:** text-embedding-3-small from OpenAI (via langchainrb).

**Metadata:** Each chunk will store the original file path, line numbers, and a reference to the Repository ID.

## Rationale
**Recursive Splitting:** Unlike fixed-length splitting, recursive splitting respects paragraph and function boundaries, keeping related technical concepts together.

**Overlap:** A 10% overlap ensures that if a crucial piece of information is cut at the end of a chunk, the next chunk still has enough context to "understand" it.

**Small Embeddings:** The text-embedding-3-small model is highly cost-effective and provides 1536 dimensions, which is more than enough for technical documentation.

**Metadata Filtering:** By storing the repository_id in the vector metadata, we can perform "Pre-filtering" in pgvector, making searches extremely fast and scoped to a single repo.

## Consequences
**Positive:** Higher accuracy in answers and better handling of large files.

**Negative:** Increased database storage (one file becomes many "chunks").

**Neutral:** Requires a more complex ingestion service (IngestionService) that manages the lifecycle of these chunks.