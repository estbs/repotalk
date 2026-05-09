require "rails_helper"

RSpec.describe IngestionJob, type: :job do
  include ActiveJob::TestHelper

  let(:repository) { create(:repository) }

  describe "#perform" do
    it "delegates to IngestionService" do
      service_double = instance_double(IngestionService, call: nil)
      allow(IngestionService).to receive(:new).with(repository).and_return(service_double)

      described_class.new.perform(repository.id)

      expect(service_double).to have_received(:call)
    end

    it "raises ActiveRecord::RecordNotFound for an unknown repository id" do
      expect { described_class.new.perform(-1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "enqueueing" do
    it "queues on the default queue" do
      expect { described_class.perform_later(repository.id) }
        .to have_enqueued_job(described_class)
        .with(repository.id)
        .on_queue("default")
    end
  end
end
