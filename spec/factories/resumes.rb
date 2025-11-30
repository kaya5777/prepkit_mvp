FactoryBot.define do
  factory :resume do
    association :user
    status { "draft" }
    raw_text { nil }
    summary { nil }
    analyzed_at { nil }

    trait :with_file do
      after(:build) do |resume|
        resume.original_file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/sample_resume.pdf")),
          filename: "sample_resume.pdf",
          content_type: "application/pdf"
        )
      end
    end

    trait :analyzing do
      status { "analyzing" }
    end

    trait :analyzed do
      status { "analyzed" }
      analyzed_at { Time.current }
      raw_text { "職務経歴書のサンプルテキスト" }
      summary { "5年の開発経験を持つWebエンジニア。Ruby on RailsとReactを使用したフルスタック開発が可能。" }

      after(:create) do |resume|
        create_list(:resume_analysis, 4, resume: resume)
      end
    end

    trait :error do
      status { "error" }
    end
  end
end
