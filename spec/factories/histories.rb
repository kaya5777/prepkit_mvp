FactoryBot.define do
  factory :history do
    association :user
    company_name { "株式会社サンプル" }
    job_description { "Webエンジニアの募集です。Ruby on Railsでの開発経験が必要です。" }
    content { "面接で質問された内容のメモ" }
    asked_at { 1.day.ago }
    memo { "全体的に良い雰囲気でした" }

    trait :with_match_analysis do
      match_score { 85 }
      match_rank { "A" }
      match_analysis do
        {
          "strengths" => [ "技術スタックが一致", "経験年数が十分" ],
          "weaknesses" => [ "特定の技術経験が不足" ],
          "recommendations" => [ "不足している技術を学習することを推奨" ]
        }
      end
    end

    trait :with_questions do
      after(:create) do |history|
        create_list(:question_answer, 3, history: history, user: history.user)
      end
    end

    trait :public do
      # 公開設定がある場合はここに追加
    end
  end
end
