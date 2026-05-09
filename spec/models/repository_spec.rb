require "rails_helper"

RSpec.describe Repository, type: :model do
  subject(:repository) { build(:repository) }

  describe "associations" do
    it { is_expected.to have_many(:document_chunks).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_uniqueness_of(:url) }
  end

  describe "status enum" do
    it "defaults to pending" do
      expect(repository.status).to eq("pending")
    end

    it "transitions through all valid statuses" do
      repository.save!
      expect { repository.ingesting! }.to change { repository.status }.from("pending").to("ingesting")
      expect { repository.ready! }.to     change { repository.status }.from("ingesting").to("ready")
      expect { repository.failed! }.to    change { repository.status }.from("ready").to("failed")
    end
  end

  describe "destroying a repository" do
    it "cascades to document_chunks" do
      repo = create(:repository)
      create_list(:document_chunk, 3, repository: repo)

      expect { repo.destroy }.to change(DocumentChunk, :count).by(-3)
    end
  end
end
