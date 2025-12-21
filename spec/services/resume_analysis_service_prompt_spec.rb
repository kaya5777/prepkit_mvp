require "rails_helper"

# プロンプト検証テスト
# このテストは実際のOpenAI APIを呼び出してプロンプトの品質を検証します
#
# 実行方法:
#   RUN_PROMPT_TESTS=true bundle exec rspec spec/services/resume_analysis_service_prompt_spec.rb
#
# 初回実行時は VCR が API レスポンスを記録します（spec/fixtures/vcr_cassettes/ に保存）
# 2回目以降は記録されたレスポンスを再生するため、API呼び出しは発生しません
#
# プロンプトを変更した場合は、以下のコマンドでカセットを削除して再記録してください:
#   rm -rf spec/fixtures/vcr_cassettes/resume_analysis_prompt_tests

RSpec.describe ResumeAnalysisService, type: :service do
  before do
    skip_unless_prompt_testing_enabled

    # ResumeTextExtractorServiceをスタブして、テキスト抽出をスキップ
    allow(ResumeTextExtractorService).to receive_message_chain(:new, :call) do |resume|
      resume.raw_text
    end
  end

  describe "Prompt validation tests", :vcr do
    # ケース1: 内容が充実した職務経歴書（高得点期待）
    context "内容が充実した職務経歴書" do
      it "全カテゴリで75点以上のスコアになる", vcr: { cassette_name: "resume_analysis_prompt_tests/excellent_resume" } do
        resume_text = <<~TEXT
          【職務要約】
          Web開発エンジニアとして7年の経験。Ruby on Railsで月間500万PVのECサイトを3件開発し、
          チームリーダーとして5名のエンジニアをマネジメント。レスポンス時間を40%改善（平均300ms→180ms）。

          【職務経歴】
          ■株式会社テックカンパニー（2020年4月～現在）
          事業内容: ECサイトの開発・運営
          従業員数: 150名

          【主要プロジェクト】
          ◆大規模ECサイトリニューアルプロジェクト（2022年10月～2023年9月）
          ・役割: チームリーダー
          ・チーム構成: エンジニア5名
          ・担当: バックエンド設計・実装、チームマネジメント
          ・成果:
            - レスポンス時間を40%改善（平均300ms→180ms）
            - 月間PVを200万→500万に増加
            - カート離脱率を15%削減
          ・使用技術: Ruby on Rails 7, PostgreSQL, Redis, AWS (EC2, S3, RDS, CloudFront), Docker

          ◆レコメンドエンジン開発（2021年4月～2022年3月）
          ・役割: バックエンドエンジニア
          ・担当: レコメンドアルゴリズム実装、API設計
          ・成果: コンバージョン率を12%向上
          ・使用技術: Ruby on Rails 6, Elasticsearch, Sidekiq

          ■株式会社スタートアップ（2017年4月～2020年3月）
          事業内容: Webサービス開発
          従業員数: 30名

          【主要プロジェクト】
          ◆社内管理システム開発（2018年～2020年）
          ・役割: フルスタックエンジニア
          ・担当: 要件定義、設計、実装、運用
          ・成果: 業務効率を30%改善
          ・使用技術: Ruby on Rails 5, React.js, PostgreSQL

          【技術スタック】
          ・バックエンド: Ruby on Rails (7年)、Node.js (2年)
          ・フロントエンド: React.js (4年)、TypeScript (3年)
          ・データベース: PostgreSQL (6年)、Redis (4年)
          ・インフラ: AWS (5年)、Docker (4年)、Kubernetes (2年)

          【資格】
          ・AWS認定ソリューションアーキテクト - アソシエイト（2021年取得）
          ・Ruby Association Certified Ruby Programmer Gold（2019年取得）
        TEXT

        resume = create_resume_with_content(resume_text)

        # ファイルを添付（validationを通過させるため）
        resume.original_file.attach(
          io: StringIO.new("dummy"),
          filename: "resume.pdf",
          content_type: "application/pdf"
        )

        result = described_class.call(resume)

        # 全カテゴリで75点以上を期待
        result.resume_analyses.each do |analysis|
          expect(analysis.score).to be >= 75,
            "#{analysis.category}カテゴリが期待より低い: #{analysis.score}点"
        end

        # 平均スコアが80点以上を期待
        avg_score = result.resume_analyses.average(:score).to_f
        expect(avg_score).to be >= 80, "平均スコアが期待より低い: #{avg_score}点"
      end
    end

    # ケース2: 基本情報はあるが具体性が不足（中程度の得点期待）
    context "基本情報はあるが具体性が不足" do
      it "スコアが40-60点の範囲になる", vcr: { cassette_name: "resume_analysis_prompt_tests/moderate_resume" } do
        resume_text = <<~TEXT
          【職務経歴】
          ■株式会社テスト（2020年4月～現在）
          ・Webアプリケーション開発を担当
          ・Ruby on Railsを使用した開発

          ■株式会社サンプル（2017年4月～2020年3月）
          ・システム開発

          【スキル】
          ・Ruby on Rails
          ・JavaScript
          ・PostgreSQL
        TEXT

        resume = create_resume_with_content(resume_text)
        resume.original_file.attach(
          io: StringIO.new("dummy"),
          filename: "resume.pdf",
          content_type: "application/pdf"
        )

        result = described_class.call(resume)

        # content カテゴリは特に低いはず（具体性・数値がないため）
        content_analysis = result.resume_analyses.find_by(category: "content")
        expect(content_analysis.score).to be_between(40, 60),
          "contentスコアが期待範囲外: #{content_analysis.score}点"

        # 平均スコアも中程度を期待
        avg_score = result.resume_analyses.average(:score).to_f
        expect(avg_score).to be_between(40, 65),
          "平均スコアが期待範囲外: #{avg_score}点"
      end
    end

    # ケース3: 最低限の情報のみ（低得点期待）
    context "最低限の情報のみで具体性がほぼない" do
      it "スコアが20-45点の範囲になる", vcr: { cassette_name: "resume_analysis_prompt_tests/minimal_resume" } do
        resume_text = <<~TEXT
          【職務経歴】
          会社名: 株式会社テスト
          期間: 2020年4月～現在
          業務: システム開発

          【スキル】
          プログラミング
        TEXT

        resume = create_resume_with_content(resume_text)
        resume.original_file.attach(
          io: StringIO.new("dummy"),
          filename: "resume.pdf",
          content_type: "application/pdf"
        )

        result = described_class.call(resume)

        # 全カテゴリで低得点を期待
        result.resume_analyses.each do |analysis|
          expect(analysis.score).to be <= 45,
            "#{analysis.category}カテゴリが期待より高い: #{analysis.score}点（最低限の情報のみなので45点以下が妥当）"
        end

        # 平均スコアも低いはず
        avg_score = result.resume_analyses.average(:score).to_f
        expect(avg_score).to be_between(20, 45),
          "平均スコアが期待範囲外: #{avg_score}点"
      end
    end

    # ケース4: 内容がほぼ空（極めて低い得点期待）
    context "内容がほぼ空のケース" do
      it "スコアが0-25点の範囲になる", vcr: { cassette_name: "resume_analysis_prompt_tests/empty_resume" } do
        resume_text = <<~TEXT
          職務経歴書

          氏名: 山田太郎
        TEXT

        resume = create_resume_with_content(resume_text)
        resume.original_file.attach(
          io: StringIO.new("dummy"),
          filename: "resume.pdf",
          content_type: "application/pdf"
        )

        result = described_class.call(resume)

        # 全カテゴリで極めて低い得点を期待
        result.resume_analyses.each do |analysis|
          expect(analysis.score).to be <= 25,
            "#{analysis.category}カテゴリが期待より高い: #{analysis.score}点（内容がほぼ空なので25点以下が妥当）"
        end
      end
    end

    # ケース5: 構成は良いが内容が薄い
    context "構成は良いが内容が薄いケース" do
      it "structureは高いがcontentは低いスコアになる", vcr: { cassette_name: "resume_analysis_prompt_tests/good_structure_poor_content" } do
        resume_text = <<~TEXT
          【職務要約】
          エンジニアとして働いています。

          【職務経歴】
          ■株式会社A（2020年4月～現在）
          職種: エンジニア
          業務内容: 開発業務

          ■株式会社B（2017年4月～2020年3月）
          職種: エンジニア
          業務内容: 開発業務

          【スキル】
          ・プログラミング
          ・データベース

          【自己PR】
          頑張ります。
        TEXT

        resume = create_resume_with_content(resume_text)
        resume.original_file.attach(
          io: StringIO.new("dummy"),
          filename: "resume.pdf",
          content_type: "application/pdf"
        )

        result = described_class.call(resume)

        structure_analysis = result.resume_analyses.find_by(category: "structure")
        content_analysis = result.resume_analyses.find_by(category: "content")

        # 構成は及第点（セクション分けはできている）
        expect(structure_analysis.score).to be >= content_analysis.score,
          "構成スコア(#{structure_analysis.score})が内容スコア(#{content_analysis.score})より低い"

        # 内容は低得点を期待（具体性がないため）
        expect(content_analysis.score).to be <= 45,
          "contentスコアが期待より高い: #{content_analysis.score}点（具体性がないので45点以下が妥当）"
      end
    end
  end

  describe "フィードバックの品質テスト", :vcr do
    context "具体的な改善提案が含まれているか" do
      it "suggestions に具体的な改善提案が含まれる", vcr: { cassette_name: "resume_analysis_prompt_tests/feedback_quality" } do
        resume_text = <<~TEXT
          【職務経歴】
          エンジニアとして3年働きました。
          Railsで開発しました。
        TEXT

        resume = create_resume_with_content(resume_text)
        resume.original_file.attach(
          io: StringIO.new("dummy"),
          filename: "resume.pdf",
          content_type: "application/pdf"
        )

        result = described_class.call(resume)

        # 全カテゴリでsuggestionsが存在することを確認
        result.resume_analyses.each do |analysis|
          suggestions = analysis.feedback["suggestions"]
          expect(suggestions).to be_an(Array)
          expect(suggestions).not_to be_empty,
            "#{analysis.category}カテゴリにsuggestionsがありません"

          # suggestionsが具体的であることを確認（最低10文字以上）
          suggestions.each do |suggestion|
            expect(suggestion.length).to be >= 10,
              "#{analysis.category}カテゴリのsuggestionが短すぎます: #{suggestion}"
          end
        end
      end
    end

    context "issues が明確に指摘されているか" do
      it "内容が薄い場合は issues が複数指摘される", vcr: { cassette_name: "resume_analysis_prompt_tests/issues_quality" } do
        resume_text = <<~TEXT
          職務経歴書

          会社で働いています。
        TEXT

        resume = create_resume_with_content(resume_text)
        resume.original_file.attach(
          io: StringIO.new("dummy"),
          filename: "resume.pdf",
          content_type: "application/pdf"
        )

        result = described_class.call(resume)

        # 少なくとも1つのカテゴリで複数のissuesが指摘されることを期待
        total_issues = result.resume_analyses.sum { |a| a.feedback["issues"].length }
        expect(total_issues).to be >= 4,
          "内容が薄いのにissuesが少なすぎます: 合計#{total_issues}個"
      end
    end
  end
end
