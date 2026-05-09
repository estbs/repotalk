class CreateDocumentChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :document_chunks do |t|
      t.references :repository, null: false, foreign_key: true
      t.text :content, null: false
      t.vector :embedding, limit: 1536
      t.string :file_path, null: false
      t.integer :start_line
      t.integer :end_line
      t.integer :chunk_index, null: false

      t.timestamps
    end

    # HNSW index for fast approximate nearest-neighbor search using cosine distance.
    # Cosine is preferred for normalized OpenAI embeddings (text-embedding-3-small).
    add_index :document_chunks, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              name: "index_document_chunks_on_embedding_hnsw"

    add_index :document_chunks, [ :repository_id, :file_path, :chunk_index ],
              name: "index_document_chunks_on_repo_file_chunk"
  end
end
