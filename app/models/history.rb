class History < ApplicationRecord
  belongs_to :user, optional: true
  has_many :question_answers, dependent: :destroy

  validates :content, presence: true

  # 一覧表示用: 大きなテキストフィールドを除外
  scope :for_listing, -> {
    select(column_names - [ "job_description", "memo", "stage_1_memo", "stage_2_memo", "stage_3_memo" ])
  }

  # マークダウンコードブロック記法を除去
  def clean_content
    content.to_s.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip
  end

  # JSONパース結果を返す（パース失敗時はnil）
  def parsed_content
    JSON.parse(clean_content, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  # パース済みコンテンツがHashかどうか
  def valid_json_content?
    parsed_content.is_a?(Hash)
  end

  # マッチング分析済みかどうか
  def match_analyzed?
    match_score.present? && match_rank.present?
  end

  # OpenAI の分析結果があるか
  def match_analyzed_openai?
    match_score_openai.present? && match_rank_openai.present?
  end

  # Gemini の分析結果があるか
  def match_analyzed_gemini?
    match_score_gemini.present? && match_rank_gemini.present?
  end

  # マッチングポイントを取得（既存カラム）
  def matching_points
    match_analysis&.dig("matching_points") || []
  end

  # マッチングポイントを取得（OpenAI）
  def matching_points_openai
    match_analysis_openai&.dig("matching_points") || []
  end

  # マッチングポイントを取得（Gemini）
  def matching_points_gemini
    match_analysis_gemini&.dig("matching_points") || []
  end

  # ギャップポイントを取得（既存カラム）
  def gap_points
    match_analysis&.dig("gap_points") || []
  end

  # ギャップポイントを取得（OpenAI）
  def gap_points_openai
    match_analysis_openai&.dig("gap_points") || []
  end

  # ギャップポイントを取得（Gemini）
  def gap_points_gemini
    match_analysis_gemini&.dig("gap_points") || []
  end

  # 懸念事項を取得（OpenAI）
  def concerns_openai
    gap_points_openai.map { |gap| gap["gap"] }.compact
  end

  # 懸念事項を取得（Gemini）
  def concerns_gemini
    gap_points_gemini.map { |gap| gap["gap"] }.compact
  end

  # アドバイスを取得（OpenAI）
  def advice_openai
    gap_points_openai.map { |gap| gap["suggestion"] }.join("\n\n")
  end

  # アドバイスを取得（Gemini）
  def advice_gemini
    gap_points_gemini.map { |gap| gap["suggestion"] }.join("\n\n")
  end

  # アピール提案を取得（既存カラム）
  def appeal_suggestions
    match_analysis&.dig("appeal_suggestions") || []
  end

  # アピール提案を取得（OpenAI）
  def appeal_suggestions_openai
    match_analysis_openai&.dig("appeal_suggestions") || []
  end

  # アピール提案を取得（Gemini）
  def appeal_suggestions_gemini
    match_analysis_gemini&.dig("appeal_suggestions") || []
  end

  # 面接アドバイスを取得（既存カラム）
  def interview_tips
    match_analysis&.dig("interview_tips") || []
  end

  # 面接アドバイスを取得（OpenAI）
  def interview_tips_openai
    match_analysis_openai&.dig("interview_tips") || []
  end

  # 面接アドバイスを取得（Gemini）
  def interview_tips_gemini
    match_analysis_gemini&.dig("interview_tips") || []
  end

  # マッチング概要を取得（既存カラム）
  def match_summary
    match_analysis&.dig("summary")
  end

  # マッチング概要を取得（OpenAI）
  def match_summary_openai
    match_analysis_openai&.dig("summary")
  end

  # マッチング概要を取得（Gemini）
  def match_summary_gemini
    match_analysis_gemini&.dig("summary")
  end

  # ランク情報を取得（既存カラム）
  def rank_info
    JobMatchAnalysisService.rank_info(match_rank)
  end

  # ランク情報を取得（OpenAI）
  def rank_info_openai
    JobMatchAnalysisService.rank_info(match_rank_openai)
  end

  # ランク情報を取得（Gemini）
  def rank_info_gemini
    JobMatchAnalysisService.rank_info(match_rank_gemini)
  end

  # ランクに応じた色クラスを取得
  def match_rank_color_class
    case match_rank
    when "S" then "bg-gradient-to-br from-yellow-400 to-yellow-600"
    when "A" then "bg-gradient-to-br from-green-400 to-green-600"
    when "B" then "bg-gradient-to-br from-blue-400 to-blue-600"
    when "C" then "bg-gradient-to-br from-orange-400 to-orange-600"
    else "bg-gradient-to-br from-gray-400 to-gray-600"
    end
  end

  # ランクに応じたバッジ色クラスを取得
  def match_rank_badge_class
    case match_rank
    when "S" then "bg-yellow-100 text-yellow-800"
    when "A" then "bg-green-100 text-green-800"
    when "B" then "bg-blue-100 text-blue-800"
    when "C" then "bg-orange-100 text-orange-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  # カジュアル面談ノートが生成済みかどうか
  def casual_note_generated?
    casual_interview_notes.present? && casual_interview_notes["summary"].present?
  end

  # ビジネス概要を取得
  def business_overview
    casual_interview_notes&.dig("business_overview") || {}
  end

  # 企業フェーズ情報を取得
  def company_phase_info
    casual_interview_notes&.dig("company_phase") || {}
  end

  # ビジネスモデル情報を取得
  def business_model_info
    casual_interview_notes&.dig("business_model") || {}
  end

  # 組織カルチャー情報を取得
  def organization_culture_info
    casual_interview_notes&.dig("organization_culture") || {}
  end

  # 最近のニュースを取得
  def recent_news_items
    casual_interview_notes&.dig("recent_news") || []
  end

  # 競合分析情報を取得
  def competitive_analysis_info
    casual_interview_notes&.dig("competitive_analysis") || {}
  end

  # 面接Tips情報を取得
  def interview_tips_info
    casual_interview_notes&.dig("interview_tips") || {}
  end

  # カジュアル面談ノート概要を取得
  def casual_note_summary
    casual_interview_notes&.dig("summary")
  end
end
