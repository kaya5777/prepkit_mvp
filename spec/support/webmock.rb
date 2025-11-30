require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before(:each) do
    # OpenAI APIのデフォルトスタブ
    stub_openai_chat_completion
  end
end

def stub_openai_chat_completion(response_body: default_openai_response)
  stub_request(:post, "https://api.openai.com/v1/chat/completions")
    .to_return(
      status: 200,
      body: response_body.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end

def default_openai_response
  {
    id: "chatcmpl-test",
    object: "chat.completion",
    created: Time.current.to_i,
    model: "gpt-4o-mini",
    choices: [
      {
        index: 0,
        message: {
          role: "assistant",
          content: mock_resume_analysis_response.to_json
        },
        finish_reason: "stop"
      }
    ],
    usage: {
      prompt_tokens: 100,
      completion_tokens: 200,
      total_tokens: 300
    }
  }
end

def mock_resume_analysis_response
  {
    summary: "5年の開発経験を持つWebエンジニア。技術スタックは幅広く、実績も豊富。",
    categories: {
      structure: {
        score: 75,
        good_points: [ "セクション分けが適切", "時系列順に整理されている" ],
        issues: [ "職務要約が簡潔すぎる" ],
        suggestions: [ "職務要約で主要な実績を具体的に記載する" ],
        examples: [
          { before: "Web開発エンジニアとして5年の経験があります。", after: "Web開発エンジニアとして5年の経験。Ruby on Railsで月間100万PVのサービスを3件開発し、チームリーダーとして5名のエンジニアをマネジメント。" }
        ]
      },
      content: {
        score: 70,
        good_points: [ "使用技術が明確" ],
        issues: [ "具体的な成果が数値化されていない" ],
        suggestions: [ "プロジェクトの規模や成果を数値で示す" ],
        examples: [
          { before: "Webアプリケーション開発を担当", after: "月間10万PVのECサイト開発を担当し、レスポンス時間を30%改善" }
        ]
      },
      expression: {
        score: 80,
        good_points: [ "文章が簡潔で読みやすい" ],
        issues: [ "専門用語の説明が不足" ],
        suggestions: [ "技術スタックごとに習熟度を明示する" ],
        examples: [
          { before: "Ruby on Rails: 5年", after: "Ruby on Rails: 5年（実務経験、フルスタック開発可能、チームリーダー経験あり）" }
        ]
      },
      layout: {
        score: 65,
        good_points: [ "シンプルで見やすい" ],
        issues: [ "視覚的な工夫が少ない" ],
        suggestions: [ "重要な実績を強調表示する" ],
        examples: [
          { before: "・Ruby on Railsを使用したバックエンド開発", after: "【主要実績】Ruby on Railsを使用したバックエンド開発（月間100万PV）" }
        ]
      }
    },
    improved_text: "職務経歴書\n\n氏名: 山田太郎\n\n【職務要約】\nWeb開発エンジニアとして5年の経験。Ruby on Railsで月間100万PVのサービスを3件開発し、チームリーダーとして5名のエンジニアをマネジメント。\n\n【職務経歴】\n■株式会社テスト（2019年4月～現在）\n【主要実績】\n・月間10万PVのECサイト開発を担当し、レスポンス時間を30%改善\n・Ruby on Railsを使用したバックエンド開発\n・React.jsを使用したフロントエンド開発\n\n【スキル】\n・Ruby on Rails: 5年（実務経験、フルスタック開発可能、チームリーダー経験あり）\n・JavaScript/React: 3年\n・PostgreSQL: 4年"
  }
end

def mock_job_match_analysis_response
  {
    match_score: 85,
    match_rank: "A",
    summary: "技術スタックが高度にマッチしており、経験年数も十分です。",
    matching_points: [
      {
        requirement: "Ruby on Rails経験3年以上",
        experience: "Ruby on Rails実務経験5年",
        strength: "求人要件を大きく上回る経験年数"
      },
      {
        requirement: "フロントエンド開発経験",
        experience: "React.js実務経験3年",
        strength: "モダンなフロントエンド技術に精通"
      }
    ],
    gap_points: [
      {
        requirement: "AWS経験",
        gap: "AWSの実務経験が明示されていない",
        suggestion: "AWSの基礎知識（EC2、S3、RDS）を学習し、個人プロジェクトで実践することを推奨"
      }
    ],
    appeal_suggestions: [
      "5年間のRails開発経験と具体的なプロジェクト成果（月間100万PV対応など）をアピール",
      "チームリーダーとしてのマネジメント経験を強調"
    ],
    interview_tips: [
      "具体的なプロジェクトでの技術選定理由と成果を説明できるよう準備",
      "AWS未経験については、学習意欲と今後のキャッチアップ計画を伝える"
    ]
  }
end
