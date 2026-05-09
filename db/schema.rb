# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_09_192517) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "document_chunks", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.text "content", null: false
    t.vector "embedding", limit: 1536
    t.string "file_path", null: false
    t.integer "start_line"
    t.integer "end_line"
    t.integer "chunk_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_document_chunks_on_embedding_hnsw", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["repository_id", "file_path", "chunk_index"], name: "index_document_chunks_on_repo_file_chunk"
    t.index ["repository_id"], name: "index_document_chunks_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.string "status", default: "pending", null: false
    t.datetime "ingested_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["url"], name: "index_repositories_on_url", unique: true
  end

  add_foreign_key "document_chunks", "repositories"
end
