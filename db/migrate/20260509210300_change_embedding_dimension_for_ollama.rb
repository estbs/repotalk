class ChangeEmbeddingDimensionForOllama < ActiveRecord::Migration[8.0]
  def up
    execute "TRUNCATE TABLE document_chunks RESTART IDENTITY"
    remove_index :document_chunks, name: "index_document_chunks_on_embedding_hnsw"
    change_column :document_chunks, :embedding, :vector, limit: 768
    add_index :document_chunks, :embedding, using: :hnsw,
              opclass: :vector_cosine_ops, name: "index_document_chunks_on_embedding_hnsw"
  end

  def down
    remove_index :document_chunks, name: "index_document_chunks_on_embedding_hnsw"
    change_column :document_chunks, :embedding, :vector, limit: 1536
    add_index :document_chunks, :embedding, using: :hnsw,
              opclass: :vector_cosine_ops, name: "index_document_chunks_on_embedding_hnsw"
  end
end
