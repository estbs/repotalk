class Repository < ApplicationRecord
  has_many :document_chunks, dependent: :destroy

  enum :status, { pending: "pending", ingesting: "ingesting", ready: "ready", failed: "failed" }

  validates :name, presence: true
  validates :url, presence: true, uniqueness: true
end
