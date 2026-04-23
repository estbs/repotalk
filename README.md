# RepoTalk 🤖📖
> **The Context-Aware Documentation Oracle**

RepoTalk is an "Anchor" project designed to demonstrate the professional integration of **Generative AI** within robust software ecosystems. It utilizes a **RAG (Retrieval-Augmented Generation)** architecture to allow developers to interact with technical documentation in a conversational and precise manner.

## 🏗️ Architecture & Stack
This project prioritizes scalability and efficiency in handling vector data.

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | **Ruby on Rails 8** | Robust backend structure and asynchronous process management. |
| **Vector Engine** | **PostgreSQL + pgvector** | Storage and high-performance semantic similarity search. |
| **AI Orchestration** | **Langchainrb** | Management of RAG flows, prompts, and LLM connections. |
| **Frontend** | **Hotwire (Turbo/Stimulus)** | Reactive interface without the overhead of a traditional SPA. |
| **Background Jobs** | **Solid Queue** | Document ingestion and processing in the background. |

## 🎯 Technical Goals
This repository is the result of an **AI-First Architecture** approach:

* **RAG Implementation:** Full ingestion pipeline (chunking, embedding, vector storage, and retrieval).
* **AI Observability:** Tracing system to validate response accuracy and reduce hallucinations.
* **Standards & Quality:**
    * **Naming:** Following Rails conventions and *Clean Code* principles.
    * **Testing:** RSpec coverage focused on data retrieval logic.
    * **Architecture:** Use of ADRs (Architecture Decision Records) to document the "why" behind every decision.

---
*Project developed as part of a software engineering portfolio specialized in AI.*