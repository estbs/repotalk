class RepositoriesController < ApplicationController
  def index
    @repositories = Repository.order(created_at: :desc)
  end

  def new
    @repository = Repository.new
  end

  def create
    @repository = Repository.new(repository_params)
    if @repository.save
      IngestionJob.perform_later(@repository.id)
      redirect_to @repository, notice: "Repository added. Ingestion started in the background."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @repository = Repository.find(params[:id])
  end

  private

  def repository_params
    params.require(:repository).permit(:name, :url)
  end
end
