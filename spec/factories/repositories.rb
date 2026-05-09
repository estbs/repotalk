FactoryBot.define do
  factory :repository do
    sequence(:name) { |n| "Repo #{n}" }
    sequence(:url)  { |n| "https://github.com/user/repo-#{n}" }
    status { "pending" }
    ingested_at { nil }

    trait :ready do
      status { "ready" }
      ingested_at { Time.current }
    end

    trait :ingesting do
      status { "ingesting" }
    end

    trait :failed do
      status { "failed" }
    end
  end
end
