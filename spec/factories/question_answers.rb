FactoryBot.define do
  factory :question_answer do
    association :history
    association :user
    question_index { 0 }
    question_text { "面接での強みを教えてください" }
    user_answer { "私の強みはチーム開発での調整力です。" }
    status { "draft" }
    score { nil }
    feedback { {} }

    trait :scored do
      status { "scored" }
      score { 75 }
      feedback do
        {
          "good_points" => ["具体的な説明ができている"],
          "improvements" => ["数値で示すとより良い"],
          "improvement_example" => "「5人のチームで開発し、月間の進捗を30%改善しました」のように具体化すると効果的です"
        }
      end
    end
  end
end
