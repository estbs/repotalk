class IngestionJob < ApplicationJob
  queue_as :default

  # Solid Queue retries on standard errors by default.
  # IngestionService::Error is raised after the repository is already marked failed,
  # so retries will re-run the full pipeline cleanly from ingesting state.
  retry_on IngestionService::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(repository_id)
    repository = Repository.find(repository_id)
    IngestionService.new(repository).call
  end
end
