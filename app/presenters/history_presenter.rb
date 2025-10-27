class HistoryPresenter
  attr_reader :history

  def initialize(history)
    @history = history
  end

  delegate :company_name, :asked_at, :memo, :job_description, :content, to: :history

  # 会社名（未登録の場合はデフォルト表示）
  def display_company_name
    company_name.presence || "（会社名未登録）"
  end

  # フォーマット済み日時
  def formatted_asked_at
    asked_at&.in_time_zone("Asia/Tokyo")&.strftime("%Y年%m月%d日 %H:%M")
  end

  # パース済みコンテンツ
  def parsed_content
    @parsed_content ||= history.parsed_content
  end

  # JSONとして有効か
  def valid_json?
    parsed_content.is_a?(Hash)
  end

  # 想定質問リスト
  def questions
    return [] unless valid_json?
    parsed_content[:questions] || parsed_content["questions"] || []
  end

  # STAR回答リスト
  def star_answers
    return [] unless valid_json?
    parsed_content[:star_answers] || parsed_content["star_answers"] || []
  end

  # 逆質問リスト
  def reverse_questions
    return [] unless valid_json?
    parsed_content[:reverse_questions] || parsed_content["reverse_questions"] || []
  end

  # 技術チェックリスト
  def tech_checklist
    return [] unless valid_json?
    parsed_content[:tech_checklist] || parsed_content["tech_checklist"] || []
  end

  # セクションが存在するか
  def has_questions?
    questions.any?
  end

  def has_star_answers?
    star_answers.any?
  end

  def has_reverse_questions?
    reverse_questions.any?
  end

  def has_tech_checklist?
    tech_checklist.any?
  end
end
