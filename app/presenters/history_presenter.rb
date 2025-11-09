class HistoryPresenter
  attr_reader :history

  def initialize(history)
    @history = history
  end

  delegate :company_name, :asked_at, :memo, :job_description, :content, :stage_1_memo, :stage_2_memo, :stage_3_memo, to: :history

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

  # 多段階面接データか判定
  def multi_stage?
    valid_json? && (parsed_content[:stage_1] || parsed_content["stage_1"]).present?
  end

  # 面接段階のデータを取得
  def stage_data(stage_number)
    return {} unless valid_json?
    stage_key = "stage_#{stage_number}"
    parsed_content[stage_key.to_sym] || parsed_content[stage_key] || {}
  end

  # 想定質問リスト（ステージ指定可能）
  def questions(stage = nil)
    if multi_stage?
      return [] if stage.nil?
      data = stage_data(stage)
      data[:questions] || data["questions"] || []
    else
      return [] unless valid_json?
      parsed_content[:questions] || parsed_content["questions"] || []
    end
  end

  # STAR回答リスト（ステージ指定可能）
  def star_answers(stage = nil)
    if multi_stage?
      return [] if stage.nil?
      data = stage_data(stage)
      data[:star_answers] || data["star_answers"] || []
    else
      return [] unless valid_json?
      parsed_content[:star_answers] || parsed_content["star_answers"] || []
    end
  end

  # 逆質問（ステージ指定可能）
  def reverse_questions(stage = nil)
    if multi_stage?
      return "" if stage.nil?
      data = stage_data(stage)
      result = data[:reverse_questions] || data["reverse_questions"]
      result || ""
    else
      return "" unless valid_json?
      result = parsed_content[:reverse_questions] || parsed_content["reverse_questions"]
      result || ""
    end
  end

  # 技術チェックリスト（ステージ指定可能）
  def tech_checklist(stage = nil)
    if multi_stage?
      return [] if stage.nil?
      data = stage_data(stage)
      data[:tech_checklist] || data["tech_checklist"] || []
    else
      return [] unless valid_json?
      parsed_content[:tech_checklist] || parsed_content["tech_checklist"] || []
    end
  end

  # セクションが存在するか（ステージ指定可能）
  def has_questions?(stage = nil)
    questions(stage).any?
  end

  def has_star_answers?(stage = nil)
    star_answers(stage).any?
  end

  def has_reverse_questions?(stage = nil)
    rq = reverse_questions(stage)
    if rq.is_a?(String)
      rq.present?
    elsif rq.is_a?(Array)
      rq.any?
    else
      false
    end
  end

  def has_tech_checklist?(stage = nil)
    tech_checklist(stage).any?
  end

  # いずれかのステージにデータがあるか
  def has_any_stage_data?
    return true unless multi_stage?
    [ 1, 2, 3 ].any? { |stage| has_questions?(stage) }
  end

  # ステージ別メモを取得
  def stage_memo(stage)
    case stage
    when 1
      stage_1_memo
    when 2
      stage_2_memo
    when 3
      stage_3_memo
    else
      nil
    end
  end

  # ステージ別メモが存在するか
  def has_stage_memo?(stage)
    stage_memo(stage).present?
  end
end
