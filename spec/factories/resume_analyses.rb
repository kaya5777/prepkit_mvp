FactoryBot.define do
  factory :resume_analysis do
    association :resume
    sequence(:category) { |n| ResumeAnalysis::CATEGORIES[n % 4] }
    score { rand(60..95) }

    feedback do
      {
        "good_points" => ["具体的な実績が記載されている", "技術スタックが明確"],
        "issues" => ["数値化できる部分が少ない"],
        "suggestions" => ["プロジェクト規模や成果を数値で示すと良い"],
        "examples" => [
          { "before" => "Webアプリケーション開発を担当", "after" => "月間10万PVのWebアプリケーション開発を担当し、レスポンス時間を30%改善" }
        ]
      }
    end

    improved_text { "改善後の職務経歴書テキスト" }

    trait :structure do
      category { "structure" }
      score { 75 }
      feedback do
        {
          "good_points" => ["セクション分けが適切"],
          "issues" => ["時系列が逆になっている"],
          "suggestions" => ["最新の経歴を上に配置する"],
          "examples" => [
            { "before" => "2019年〜2021年の経歴が最初", "after" => "2023年〜現在の経歴を最初に配置" }
          ]
        }
      end
    end

    trait :content do
      category { "content" }
      score { 80 }
    end

    trait :expression do
      category { "expression" }
      score { 85 }
    end

    trait :layout do
      category { "layout" }
      score { 70 }
    end
  end
end
