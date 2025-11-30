FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "テストユーザー" }

    trait :with_google_oauth do
      provider { "google_oauth2" }
      sequence(:uid) { |n| "google_uid_#{n}" }
      avatar_url { "https://example.com/avatar.jpg" }
    end

    trait :with_resume do
      after(:create) do |user|
        create(:resume, :analyzed, :with_file, user: user)
      end
    end

    trait :with_histories do
      after(:create) do |user|
        create_list(:history, 3, user: user)
      end
    end
  end
end
