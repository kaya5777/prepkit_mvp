class InterviewKitGeneratorService
  class APIKeyMissingError < StandardError; end
  class ContentBlankError < StandardError; end
  class ParseError < StandardError; end
  class AuthenticationError < StandardError; end

  def self.call(job_description, company_name = nil)
    new(job_description, company_name).call
  end

  def initialize(job_description, company_name = nil)
    @job_description = job_description
    @company_name = company_name
  end

  def call
    validate_api_key!

    response = generate_with_openai
    content = extract_content_from_response(response)
    parsed_result = parse_json_content(content)

    # 履歴を保存
    history = save_history(content)

    { result: parsed_result, history: history }
  rescue OpenAI::Error => e
    handle_openai_error(e)
  end

  private

  def validate_api_key!
    if ENV["OPENAI_API_KEY"].to_s.strip.empty?
      raise APIKeyMissingError, "OpenAI の API キーが設定されていません（code: missing_api_key）。管理者にお問い合わせください。"
    end
  end

  def generate_with_openai
    client = OpenAI::Client.new
    client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: build_prompt }
      ],
      temperature: 0.7
    )
  end

  def extract_content_from_response(response)
    first_choice = response.respond_to?(:choices) ? response.choices&.first : nil
    message = first_choice.respond_to?(:message) ? first_choice.message : (first_choice.is_a?(Hash) ? first_choice[:message] : nil)
    content = message.respond_to?(:content) ? message.content : (message.is_a?(Hash) ? message[:content] : nil)

    if content.blank?
      Rails.logger.error "OpenAI 応答に content がありません: #{response.inspect}"
      raise ContentBlankError, "生成に失敗しました（code: content_blank）。しばらくしてから再度お試しください。"
    end

    content
  end

  def parse_json_content(content)
    json_string = content.gsub(/\A```json|```|\A```|\Z```/m, "").strip
    parsed = JSON.parse(json_string, symbolize_names: true)

    # questionsが配列でない場合（オブジェクトの配列など）、文字列の配列に変換
    if parsed[:questions].is_a?(Array) && parsed[:questions].first.is_a?(Hash)
      parsed[:questions] = parsed[:questions].map { |q| q[:question] || q["question"] }
    end

    # reverse_questionsも同様に変換
    if parsed[:reverse_questions].is_a?(Array) && parsed[:reverse_questions].first.is_a?(Hash)
      parsed[:reverse_questions] = parsed[:reverse_questions].map { |q| q[:question] || q["question"] || q.to_s }
    end

    # tech_checklistも同様に変換
    if parsed[:tech_checklist].is_a?(Array) && parsed[:tech_checklist].first.is_a?(Hash)
      parsed[:tech_checklist] = parsed[:tech_checklist].map { |item| item[:item] || item["item"] || item.to_s }
    end

    parsed
  rescue JSON::ParserError => e
    Rails.logger.error "JSON パース失敗: #{e.message}"
    raise ParseError, "生成結果の形式が不正でした（#{e.message}）。もう一度お試しください。"
  end

  def save_history(content)
    History.create!(
      content: content,
      memo: "",
      asked_at: Time.current,
      job_description: @job_description,
      company_name: @company_name
    )
  end

  def system_prompt
    <<~PROMPT
    あなたは採用面接の専門家です。求人票から面接対策情報をJSON形式で生成します。
    出力形式: {"questions":[],"star_answers":[],"reverse_questions":[],"tech_checklist":[]}
    PROMPT
  end

  def build_prompt
    <<~PROMPT
    求人票を分析し、面接対策情報を以下の形式のJSONで生成してください。

    【求人票】
    #{@job_description}

    【出力形式】
    {
      "questions": ["質問文1", "質問文2", "質問文3", "質問文4", "質問文5"],
      "star_answers": [
        {"question": "質問文1", "situation": "状況", "task": "課題", "action": "行動", "result": "成果"},
        {"question": "質問文2", "situation": "状況", "task": "課題", "action": "行動", "result": "成果"},
        ...5個すべて
      ],
      "reverse_questions": ["逆質問1", "逆質問2", ...],
      "tech_checklist": ["確認項目1", "確認項目2", ...]
    }

    【要件】
    - questions: 技術質問3個+行動面接質問2個の計5個（文字列の配列）
    - star_answers: questionsの5問全てに対応するSTAR回答（各要素2文程度）
    - reverse_questions: 深掘りできる逆質問5-7個（文字列の配列）
    - tech_checklist: 面接前の確認項目5-8個（文字列の配列）

    ※questionsとreverse_questions、tech_checklistは必ず文字列の配列にすること
    ※求人内容に特化した具体的な内容にする
    ※JSONのみ出力（説明文不要）
    PROMPT
  end

  def handle_openai_error(error)
    if error.class.to_s.include?("AuthenticationError") || error.message.include?("status=>401")
      raise AuthenticationError, "OpenAI への認証に失敗しました（401）。APIキーが未設定または無効です。管理者にお問い合わせください。"
    else
      Rails.logger.error "想定外のエラー: #{error.class} #{error.message}"
      raise error
    end
  end
end
