require "rails_helper"

RSpec.describe DocumentChunk, type: :model do
  subject(:chunk) { build(:document_chunk) }

  describe "associations" do
    it { is_expected.to belong_to(:repository) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:file_path) }
    it { is_expected.to validate_presence_of(:chunk_index) }
    it { is_expected.to validate_numericality_of(:chunk_index).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe ".search" do
    # Vectors used here are unit vectors along cardinal dimensions so that
    # cosine similarity is exact and predictable without floating-point noise.
    #
    # dim_0 = [1, 0, 0, ...]  dim_1 = [0, 1, 0, ...]  dim_2 = [0, 0, 1, ...]
    #
    # Querying with dim_0 must return the dim_0 chunk first (distance 0),
    # then dim_1 / dim_2 (distance 1 — orthogonal).

    let(:repo)       { create(:repository) }
    let(:other_repo) { create(:repository) }

    let(:dim_0) { Array.new(1536, 0.0).tap { |v| v[0] = 1.0 } }
    let(:dim_1) { Array.new(1536, 0.0).tap { |v| v[1] = 1.0 } }
    let(:dim_2) { Array.new(1536, 0.0).tap { |v| v[2] = 1.0 } }

    let!(:closest_chunk)   { create(:document_chunk, repository: repo, embedding: dim_0, chunk_index: 0) }
    let!(:distant_chunk)   { create(:document_chunk, repository: repo, embedding: dim_1, chunk_index: 1) }
    let!(:unrelated_chunk) { create(:document_chunk, repository: other_repo, embedding: dim_0, chunk_index: 0) }

    it "returns the most similar chunk first" do
      results = described_class.search(dim_0, repository: repo)
      expect(results.first).to eq(closest_chunk)
    end

    it "orders results by ascending cosine distance" do
      results = described_class.search(dim_0, repository: repo)
      expect(results).to eq([ closest_chunk, distant_chunk ])
    end

    it "scopes results to the given repository" do
      results = described_class.search(dim_0, repository: repo)
      expect(results).not_to include(unrelated_chunk)
    end

    it "respects the limit parameter" do
      create(:document_chunk, repository: repo, embedding: dim_2, chunk_index: 2)
      results = described_class.search(dim_0, repository: repo, limit: 1)
      expect(results.to_a.count).to eq(1)
    end
  end
end
