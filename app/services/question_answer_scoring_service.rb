class QuestionAnswerScoringService
  class ScoringError < StandardError; end

  SCORING_CRITERIA = {
    accuracy: { weight: 30, description: "内容の正確性" },
    coverage: { weight: 25, description: "網羅性（回答のポイントを押さえているか）" },
    specificity: { weight: 20, description: "具体性（具体例があるか）" },
    level_fit: { weight: 15, description: "レベル適合性（募集職種に合っているか）" },
    conciseness: { weight: 10, description: "簡潔性（冗長すぎないか）" }
  }.freeze

  def self.call(question_data, user_answer, level = nil)
    new(question_data, user_answer, level).call
  end

  def initialize(question_data, user_answer, level = nil)
    @question = question_data[:question] || question_data["question"]
    @intent = question_data[:intent] || question_data["intent"]
    @answer_points = question_data[:answer_points] || question_data["answer_points"] || []
    @level = level || question_data[:level] || question_data["level"] || "Mid-level"
    @user_answer = user_answer
  end

  def call
    validate_inputs!
    response = generate_scoring_with_openai
    parse_scoring_response(response)
  rescue StandardError => e
    Rails.logger.error "API Error: #{e.class} - #{e.message}"
    raise ScoringError, "採点に失敗しました。しばらくしてから再度お試しください。"
  end

  private

  def validate_inputs!
    raise ScoringError, "質問文が指定されていません" if @question.blank?
    raise ScoringError, "回答が入力されていません" if @user_answer.blank?
  end

  def generate_scoring_with_openai
    client = OpenAI::Client.new
    client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: build_scoring_prompt }
      ],
      temperature: 0.5
    )
  end

  def system_prompt
    <<~PROMPT
    あなたは面接対策の専門家です。ユーザーの回答を採点し、建設的なフィードバックを提供します。
    出力は必ずJSON形式で行ってください。
    PROMPT
  end

  def build_scoring_prompt
    <<~PROMPT
    以下の面接質問に対するユーザーの回答を採点してください。

    【質問】
    #{@question}

    【面接官の意図】
    #{@intent}

    【回答のポイント】
    #{@answer_points.map.with_index(1) { |point, i| "#{i}. #{point}" }.join("\n")}

    【募集職種レベル】
    #{@level}

    【ユーザーの回答】
    #{@user_answer}

    【採点基準（合計100点）】
    #{scoring_criteria_text}

    【出力形式（JSON）】
    {
      "score": 85,
      "good_points": ["良かった点1", "良かった点2", "良かった点3"],
      "improvements": ["改善点1", "改善点2"],
      "improvement_example": "改善例を具体的に1-2文で記述"
    }

    ※good_pointsは3-4個、improvementsは2-3個
    ※improvement_exampleは具体的で実践的な内容にする
    ※JSONのみ出力（説明文不要）
    PROMPT
  end

  def scoring_criteria_text
    SCORING_CRITERIA.map do |key, data|
      "- #{data[:description]}（#{data[:weight]}点）"
    end.join("\n")
  end

  def parse_scoring_response(response)
    content = response.choices&.first&.message&.content
    raise ScoringError, "AIからの応答が空です" if content.blank?

    json_string = content.gsub(/\A```json|```|\A```|\Z```/m, "").strip
    parsed = JSON.parse(json_string, symbolize_names: true)

    validate_parsed_result!(parsed)
    normalize_result(parsed)
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parse error: #{e.message}\nContent: #{content}"
    raise ScoringError, "採点結果の解析に失敗しました"
  end

  def validate_parsed_result!(parsed)
    raise ScoringError, "スコアが含まれていません" unless parsed[:score]
    raise ScoringError, "良かった点が含まれていません" unless parsed[:good_points]
    raise ScoringError, "改善点が含まれていません" unless parsed[:improvements]
  end

  def normalize_result(parsed)
    {
      score: parsed[:score].to_i.clamp(0, 100),
      good_points: Array(parsed[:good_points]),
      improvements: Array(parsed[:improvements]),
      improvement_example: parsed[:improvement_example] || ""
    }
  end
end
