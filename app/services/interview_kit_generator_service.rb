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
        { role: "system", content: "あなたは面接官です。JSON形式で出力してください。" },
        { role: "user", content: build_prompt }
      ]
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
    JSON.parse(json_string, symbolize_names: true)
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

  def build_prompt
    <<~PROMPT
    以下の求人票をもとに面接対策用の情報を生成してください。
    JSON形式で出力してください。

    出力フォーマット:
    {
      "questions": ["質問1", "質問2", ...],
      "star_answers": [
        {"question": "質問1", "situation": "...", "task": "...", "action": "...", "result": "..."}
      ],
      "reverse_questions": ["逆質問1", "逆質問2"],
      "tech_checklist": ["チェック項目1", "チェック項目2"]
    }

    求人票:
    #{@job_description}
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
