require "rails_helper"

# プロンプト検証テスト
# このテストは実際のOpenAI APIを呼び出してプロンプトの品質を検証します
#
# 実行方法:
#   RUN_PROMPT_TESTS=true bundle exec rspec spec/services/job_match_analysis_service_prompt_spec.rb
#
# 初回実行時は VCR が API レスポンスを記録します（spec/fixtures/vcr_cassettes/ に保存）
# 2回目以降は記録されたレスポンスを再生するため、API呼び出しは発生しません
#
# プロンプトを変更した場合は、以下のコマンドでカセットを削除して再記録してください:
#   rm -rf spec/fixtures/vcr_cassettes/job_match_analysis_prompt_tests

RSpec.describe JobMatchAnalysisService, type: :service do
  before { skip_unless_prompt_testing_enabled }

  describe "Prompt validation tests", :vcr do
    # ケース1: 同業種・同職種・経験豊富（S判定期待）
    context "同業種・同職種・経験豊富なケース" do
      it "スコアが90点以上のS判定になる", vcr: { cassette_name: "job_match_analysis_prompt_tests/perfect_match" } do
        resume = create_resume_with_content(<<~TEXT)
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

        history = create_history_with_job(
          company: "テック株式会社",
          description: <<~DESC
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
        )

        result = described_class.call(history, resume)

        expect(result.match_score).to be >= 90, "期待: 90点以上, 実際: #{result.match_score}点"
        expect(result.match_rank).to eq("S"), "期待: S判定, 実際: #{result.match_rank}判定"
      end
    end

    # ケース2: 同業種・同職種・経験十分（A判定期待）
    context "同業種・同職種・経験十分なケース" do
      it "スコアが80-89点のA判定になる", vcr: { cassette_name: "job_match_analysis_prompt_tests/good_match" } do
        resume = create_resume_with_content(<<~TEXT)
          【職務経歴】
          Rails エンジニア、実務経験4年

          【主要実績】
          ・月間10万PVのWebサービス開発
          ・Rails 6 から Rails 7 へのアップグレード対応

          【技術スタック】
          ・Ruby on Rails: 4年
          ・React.js: 2年
          ・PostgreSQL: 3年
        TEXT

        history = create_history_with_job(
          company: "スタートアップ株式会社",
          description: <<~DESC
            【募集職種】
            Rails エンジニア

            【必須要件】
            ・Ruby on Rails の実務経験 3年以上
            ・Webサービスの開発経験
          DESC
        )

        result = described_class.call(history, resume)

        expect(result.match_score).to be_between(80, 89), "期待: 80-89点, 実際: #{result.match_score}点"
        expect(result.match_rank).to eq("A"), "期待: A判定, 実際: #{result.match_rank}判定"
      end
    end

    # ケース3: 同業種・同職種・経験やや不足（B判定期待）
    context "同業種・同職種・経験やや不足のケース" do
      it "スコアが70-79点のB判定になる", vcr: { cassette_name: "job_match_analysis_prompt_tests/moderate_match" } do
        resume = create_resume_with_content(<<~TEXT)
          【職務経歴】
          Rails エンジニア、実務経験2年

          【主要実績】
          ・社内管理システムの開発
          ・CRUD機能の実装

          【技術スタック】
          ・Ruby on Rails: 2年
          ・PostgreSQL: 2年
        TEXT

        history = create_history_with_job(
          company: "成長企業株式会社",
          description: <<~DESC
            【募集職種】
            Rails エンジニア

            【必須要件】
            ・Ruby on Rails の実務経験 3年以上
            ・大規模サービスの開発経験
            ・AWS の実務経験
          DESC
        )

        result = described_class.call(history, resume)

        expect(result.match_score).to be_between(70, 79), "期待: 70-79点, 実際: #{result.match_score}点"
        expect(result.match_rank).to eq("B"), "期待: B判定, 実際: #{result.match_rank}判定"
      end
    end

    # ケース4: 業種同じ・職種異なる（C判定期待）
    context "業種同じ・職種異なるケース" do
      it "スコアが最高でも75点以下のB判定またはC判定になる", vcr: { cassette_name: "job_match_analysis_prompt_tests/different_role_same_industry" } do
        resume = create_resume_with_content(<<~TEXT)
          【職務経歴】
          フロントエンドエンジニア、実務経験5年

          【主要実績】
          ・React/TypeScript を使用したSPA開発
          ・コンポーネント設計とパフォーマンス最適化

          【技術スタック】
          ・React.js: 5年
          ・TypeScript: 5年
          ・Next.js: 3年
        TEXT

        history = create_history_with_job(
          company: "Web企業株式会社",
          description: <<~DESC
            【募集職種】
            バックエンドエンジニア（Ruby on Rails）

            【必須要件】
            ・Ruby on Rails の実務経験 3年以上
            ・API設計・実装経験
            ・データベース設計経験
          DESC
        )

        result = described_class.call(history, resume)

        expect(result.match_score).to be <= 75, "期待: 75点以下, 実際: #{result.match_score}点"
        expect(result.match_rank).to be_in([ "B", "C", "D" ]), "期待: B/C/D判定, 実際: #{result.match_rank}判定"
      end
    end

    # ケース5: 異業種・異職種（C判定またはD判定期待）
    context "異業種・異職種のケース" do
      it "スコアが最高でも65点以下のC判定またはD判定になる", vcr: { cassette_name: "job_match_analysis_prompt_tests/complete_mismatch" } do
        resume = create_resume_with_content(<<~TEXT)
          【職務経歴】
          営業職、実務経験10年

          【主要実績】
          ・年間売上3億円達成
          ・新規顧客開拓100社
          ・営業チームリーダー経験5年

          【スキル】
          ・営業戦略立案
          ・顧客折衝
          ・チームマネジメント
        TEXT

        history = create_history_with_job(
          company: "IT企業株式会社",
          description: <<~DESC
            【募集職種】
            Rails エンジニア

            【必須要件】
            ・Ruby on Rails の実務経験 3年以上
            ・Webアプリケーション開発経験
            ・Git を使用したチーム開発経験
          DESC
        )

        result = described_class.call(history, resume)

        expect(result.match_score).to be <= 65, "期待: 65点以下, 実際: #{result.match_score}点"
        expect(result.match_rank).to be_in([ "C", "D" ]), "期待: C/D判定, 実際: #{result.match_rank}判定"
      end
    end

    # ケース6: 異業種・異職種・未経験（D判定期待）
    context "異業種・異職種・完全未経験のケース" do
      it "スコアが59点以下のD判定になる", vcr: { cassette_name: "job_match_analysis_prompt_tests/no_experience" } do
        resume = create_resume_with_content(<<~TEXT)
          【職務経歴】
          小売店店員、実務経験3年

          【主な業務】
          ・接客対応
          ・在庫管理
          ・レジ業務

          【スキル】
          ・接客スキル
          ・基本的なPCスキル（Excel、Word）
        TEXT

        history = create_history_with_job(
          company: "テック企業株式会社",
          description: <<~DESC
            【募集職種】
            シニアRails エンジニア

            【必須要件】
            ・Ruby on Rails の実務経験 5年以上
            ・大規模サービスの設計・開発経験
            ・技術選定やアーキテクチャ設計の経験
          DESC
        )

        result = described_class.call(history, resume)

        expect(result.match_score).to be <= 59, "期待: 59点以下, 実際: #{result.match_score}点"
        expect(result.match_rank).to eq("D"), "期待: D判定, 実際: #{result.match_rank}判定"
      end
    end
  end

  describe "プロンプトの一貫性テスト", :vcr do
    # 同じ入力で複数回実行しても結果が大きく変わらないことを確認
    context "同じ入力で複数回実行" do
      it "スコアが±5点以内で安定している", vcr: { cassette_name: "job_match_analysis_prompt_tests/consistency_test" } do
        resume = create_resume_with_content(<<~TEXT)
          【職務経歴】
          Rails エンジニア、実務経験5年

          【技術スタック】
          ・Ruby on Rails: 5年
          ・PostgreSQL: 4年
        TEXT

        history = create_history_with_job(
          company: "テスト株式会社",
          description: "Rails エンジニア募集（経験3年以上）"
        )

        # 3回実行して結果を記録
        scores = 3.times.map do
          result = described_class.call(history, resume)
          history.reload
          result.match_score
        end

        # スコアの変動が±5点以内であることを確認
        score_range = scores.max - scores.min
        expect(score_range).to be <= 5, "スコアの変動が大きすぎます: #{scores.inspect}"
      end
    end
  end
end
