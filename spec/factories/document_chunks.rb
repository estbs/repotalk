FactoryBot.define do
  factory :document_chunk do
    repository
    sequence(:chunk_index) { |n| n }
    content { "This is a sample code chunk for testing." }
    file_path { "app/models/user.rb" }
    start_line { 1 }
    end_line { 20 }
    # Sparse unit vector along dimension 0 — safe placeholder when embedding is not under test.
    embedding { Array.new(768, 0.0).tap { |v| v[0] = 1.0 } }
  end
end
