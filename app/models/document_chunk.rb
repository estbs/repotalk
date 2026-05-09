class DocumentChunk < ApplicationRecord
  belongs_to :repository

  has_neighbors :embedding

  validates :content, presence: true
  validates :file_path, presence: true
  validates :chunk_index, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Pre-filter by repository, then rank by cosine distance to query_embedding.
  # This is the primary retrieval path for the RAG pipeline (ADR 0003).
  def self.search(query_embedding, repository:, limit: 5)
    where(repository: repository)
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)
  end
end
