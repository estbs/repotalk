# ADR 0002: Vector Database Selection
## Status
Accepted

## Context
RepoTalk requires a storage solution for high-dimensional vector embeddings generated from technical documentation. We need a system that allows for efficient similarity searches (k-Nearest Neighbors) to retrieve relevant context for the RAG pipeline. The options considered were dedicated vector databases (Pinecone, Milvus) or an extension of our primary relational database.

## Decision
We will use PostgreSQL with the pgvector extension.

This decision allows us to keep all application data (users, repositories, documents) and their corresponding embeddings in a single, ACID-compliant database. We will use the neighbor gem or langchainrb to interface with the vector columns within our Ruby on Rails models.

## Rationale
**Operational Simplicity:** Avoids the overhead of managing a separate database cluster or a third-party SaaS for vectors.

**Data Integrity:** Allows for atomic transactions and relational queries combined with semantic search (e.g., "Find relevant chunks only within this specific repository").

**Performance:** pgvector provides HNSW and IVFFlat indexing, which are sufficient for the scale of a portfolio "Anchor" project.

**Cost:** Using our existing PostgreSQL instance (via Docker or RDS) is significantly cheaper than dedicated AI database providers.

## Consequences
**Positive:** Reduced infrastructure complexity and unified backup/restore strategy.

**Negative:** Increased CPU and memory load on the PostgreSQL instance during index builds and heavy search operations.

**Neutral:** We must ensure the production environment (e.g., Heroku, Render, or Docker) supports the pgvector extension.