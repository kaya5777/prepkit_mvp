class History < ApplicationRecord
  belongs_to :user, optional: true
  has_many :question_answers, dependent: :destroy

  validates :content, presence: true

  # 一覧表示用: 大きなテキストフィールドを除外
  scope :for_listing, -> {
    select(column_names - ['job_description', 'memo', 'stage_1_memo', 'stage_2_memo', 'stage_3_memo'])
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

  # マッチングポイントを取得
  def matching_points
    match_analysis&.dig("matching_points") || []
  end

  # ギャップポイントを取得
  def gap_points
    match_analysis&.dig("gap_points") || []
  end

  # アピール提案を取得
  def appeal_suggestions
    match_analysis&.dig("appeal_suggestions") || []
  end

  # 面接アドバイスを取得
  def interview_tips
    match_analysis&.dig("interview_tips") || []
  end

  # マッチング概要を取得
  def match_summary
    match_analysis&.dig("summary")
  end

  # ランク情報を取得
  def rank_info
    JobMatchAnalysisService.rank_info(match_rank)
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
end
