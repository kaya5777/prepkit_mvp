# プロンプトテストのデバッグ用ヘルパー
# 実際のスコアとテストの期待値が一致しない場合の調査に使用

# 使い方:
# 1. このファイルをrails consoleで読み込む
#    load 'spec/services/prompt_test_debug_helper.rb'
#
# 2. デバッグ実行
#    PromptTestDebugHelper.debug_perfect_match_case

module PromptTestDebugHelper
  def self.debug_perfect_match_case
    puts "\n" + "=" * 80
    puts "S判定テストケースのデバッグ"
    puts "=" * 80

    user = User.first || User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # テストと同じデータを作成
    resume_text = <<~TEXT
      【職務経歴】
      Rails エンジニア、実務経験7年

      【主要実績】
      ・月間500万PVのECサイトをRuby on Railsで開発
      ・レスポンス時間を40%改善（平均300ms→180ms）
      ・チームリード経験3年（5名のエンジニアをマネジメント）

      【技術スタック】
      ・Ruby on Rails: 7年（フルスタック開発、設計・実装・運用すべて経験）
      ・React.js: 4年
      ・PostgreSQL: 6年
      ・AWS (EC2, S3, RDS, CloudFront): 5年
      ・Docker: 4年

      【資格】
      ・AWS認定ソリューションアーキテクト
    TEXT

    job_description = <<~DESC
      【募集職種】
      Rails エンジニア

      【必須要件】
      ・Ruby on Rails の実務経験 5年以上
      ・大規模Webサービスの開発・運用経験
      ・チーム開発経験

      【歓迎要件】
      ・AWS の実務経験
      ・フロントエンド開発経験（React等）
      ・チームマネジメント経験
    DESC

    # Resumeを作成
    resume = Resume.create!(
      user: user,
      raw_text: resume_text,
      status: "analyzed",
      analyzed_at: Time.current
    )

    # Historyを作成
    history = History.create!(
      user: user,
      company_name: "テック株式会社",
      job_description: job_description
    )

    puts "\n【入力データ】"
    puts "職務経歴書の長さ: #{resume.raw_text.length}文字"
    puts "求人情報の長さ: #{history.job_description.length}文字"

    puts "\n【分析実行中...】"
    result = JobMatchAnalysisService.call(history, resume)

    puts "\n【結果】"
    puts "スコア: #{result.match_score}点"
    puts "ランク: #{result.match_rank}"
    puts "\n期待: 90点以上のS判定"
    puts "差異: #{90 - result.match_score}点"

    if result.match_score < 90
      puts "\n【警告】期待より低いスコアです！"
      puts "\n【分析詳細】"
      puts "マッチングポイント数: #{result.match_analysis['matching_points']&.length || 0}"
      puts "ギャップポイント数: #{result.match_analysis['gap_points']&.length || 0}"

      if result.match_analysis['summary']
        puts "\n総合評価:"
        puts result.match_analysis['summary']
      end
    else
      puts "\n【成功】期待通りのスコアです"
    end

    puts "\n" + "=" * 80

    # クリーンアップ
    history.destroy
    resume.destroy

    result
  end

  def self.compare_with_test
    puts "\nテストの期待値との比較:"
    puts "S判定: 90-100点"
    puts "A判定: 80-89点"
    puts "B判定: 70-79点"
    puts "C判定: 60-69点"
    puts "D判定: 0-59点"
  end
end
