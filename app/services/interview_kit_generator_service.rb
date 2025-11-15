class InterviewKitGeneratorService
  class APIKeyMissingError < StandardError; end
  class ContentBlankError < StandardError; end
  class ParseError < StandardError; end
  class AuthenticationError < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    あなたは採用面接の専門家です。求人票から、1次面接（現場クラス）、2次面接（マネージャークラス）、3次面接（社長・役員クラス）の3段階の面接対策情報をJSON形式で生成します。
  PROMPT

  OUTPUT_FORMAT = <<~FORMAT.freeze
    {
      "stage_1": {
        "questions": [
          {
            "question": "1次面接の質問文",
            "intent": "この質問で面接官が知りたいこと（1-2文）",
            "answer_points": ["回答のポイント1", "回答のポイント2", "回答のポイント3"],
            "level": "募集職種のレベル"
          }
        ],
        "reverse_questions": "1次面接での逆質問のアドバイス（2-3行の文章）",
        "tech_checklist": ["1次面接で確認すべき項目1", "確認項目2", ...]
      },
      "stage_2": {
        "questions": [...],
        "reverse_questions": "2次面接での逆質問のアドバイス（2-3行の文章）",
        "tech_checklist": ["2次面接で確認すべき項目1", ...]
      },
      "stage_3": {
        "questions": [...],
        "reverse_questions": "3次面接での逆質問のアドバイス（2-3行の文章）",
        "tech_checklist": ["3次面接で確認すべき項目1", ...]
      }
    }

    ※各段階の特徴：
    - stage_1 (1次面接 - 現場クラス): 技術的な深掘り、実装経験、問題解決能力を重視
    - stage_2 (2次面接 - マネージャークラス): チーム適合性、コミュニケーション力、マネジメント経験を重視
    - stage_3 (3次面接 - 社長・役員クラス): ビジョン共感、キャリア志向、経営視点での貢献を重視
  FORMAT

  LEVEL_EXAMPLES = <<~EXAMPLES.freeze
    例：
    - 「Junior Engineer」募集の場合
      → 基礎知識の理解度、学習意欲、成長ポテンシャルを示すポイント

    - 「Senior Engineer」募集の場合
      → 実装力だけでなく、設計判断、技術選定の根拠、パフォーマンス最適化の経験など

    - 「Engineering Manager (EM)」募集の場合
      → チームマネジメント経験、1on1やパフォーマンス評価の手法、技術的意思決定とビジネス目標のバランス、採用・育成の実績など

    - 「Tech Lead」募集の場合
      → アーキテクチャ設計の主導経験、技術的負債の解消戦略、メンバーのコードレビューやメンタリング、ステークホルダーとの技術コミュニケーションなど
  EXAMPLES

  REVERSE_QUESTION_EXAMPLES = <<~EXAMPLES.freeze
    例：
    - Junior Engineer募集の場合
      「技術スタックの学習機会や、メンターシップ制度の有無について確認しましょう。成長環境として、コードレビューの文化やペアプログラミングの頻度、オンボーディングプロセスについて聞くことで、学習意欲をアピールできます。」

    - Senior Engineer募集の場合
      「技術的意思決定のプロセスや、アーキテクチャ設計への関与度について確認しましょう。技術的負債への取り組み方や、新技術導入の判断基準、チーム内での技術リーダーシップの期待値について聞くことで、シニアとしての視点をアピールできます。」

    - Engineering Manager募集の場合
      「チームの構成や評価制度、1on1の頻度と内容について確認しましょう。採用プロセスへの関与度、キャリア開発の支援体制、エンジニアリングとビジネス目標のバランスをどう取っているかを聞くことで、マネジメント経験と関心をアピールできます。」
  EXAMPLES

  def self.call(job_description, company_name = nil, current_user = nil)
    new(job_description, company_name, current_user).call
  end

  def initialize(job_description, company_name = nil, current_user = nil)
    @job_description = job_description
    @company_name = company_name
    @current_user = current_user
  end

  def call
    validate_api_key!

    response = generate_with_openai
    content = extract_content_from_response(response)
    parsed_result = parse_json_content(content)

    # 履歴を保存
    history = save_history(content)

    { result: parsed_result, history: history }
  rescue StandardError => e
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
    content = extract_nested_content(response)

    if content.blank?
      Rails.logger.error "OpenAI 応答に content がありません: #{response.inspect}"
      raise ContentBlankError, "生成に失敗しました（code: content_blank）。しばらくしてから再度お試しください。"
    end

    content
  end

  def extract_nested_content(response)
    first_choice = safe_access(response, :choices)&.first
    message = safe_access(first_choice, :message)
    safe_access(message, :content)
  end

  def safe_access(object, method)
    return nil unless object
    object.respond_to?(method) ? object.public_send(method) : object[method]
  end

  def parse_json_content(content)
    json_string = content.gsub(/\A```json|```|\A```|\Z```/m, "").strip
    parsed = JSON.parse(json_string, symbolize_names: true)

    normalize_parsed_content(parsed)
  rescue JSON::ParserError => e
    Rails.logger.error "JSON パース失敗: #{e.message}"
    raise ParseError, "生成結果の形式が不正でした（#{e.message}）。もう一度お試しください。"
  end

  def normalize_parsed_content(parsed)
    parsed[:questions] = normalize_questions(parsed[:questions]) if parsed[:questions].is_a?(Array)
    parsed[:reverse_questions] = normalize_reverse_questions(parsed[:reverse_questions])
    parsed[:tech_checklist] = normalize_tech_checklist(parsed[:tech_checklist])
    parsed
  end

  def normalize_questions(questions)
    questions.map do |q|
      q.is_a?(Hash) ? normalize_question_hash(q) : question_from_string(q)
    end
  end

  def normalize_question_hash(question)
    {
      question: question[:question] || question["question"],
      intent: question[:intent] || question["intent"] || "",
      answer_points: question[:answer_points] || question["answer_points"] || [],
      level: question[:level] || question["level"] || ""
    }
  end

  def question_from_string(string)
    {
      question: string.to_s,
      intent: "",
      answer_points: [],
      level: ""
    }
  end

  def normalize_reverse_questions(reverse_questions)
    return "" unless reverse_questions

    if reverse_questions.is_a?(Array)
      reverse_questions.map { |q| q.is_a?(Hash) ? (q[:question] || q["question"] || q.to_s) : q.to_s }.join("\n")
    elsif reverse_questions.is_a?(String)
      reverse_questions
    else
      ""
    end
  end

  def normalize_tech_checklist(tech_checklist)
    return tech_checklist unless tech_checklist.is_a?(Array) && tech_checklist.first.is_a?(Hash)

    tech_checklist.map { |item| item[:item] || item["item"] || item.to_s }
  end

  def save_history(content)
    History.create!(
      content: content,
      memo: "",
      asked_at: Time.current,
      job_description: @job_description,
      company_name: @company_name,
      user: @current_user
    )
  end

  def system_prompt
    SYSTEM_PROMPT
  end

  def build_prompt
    <<~PROMPT
    求人票を分析し、面接対策情報を以下の形式のJSONで生成してください。

    【求人票】
    #{@job_description}

    【出力形式】
    #{OUTPUT_FORMAT}

    【重要な指示】

    1. questions: 技術質問3個+行動面接質問2個の計5個
       - question: 質問文
       - intent: 面接官がこの質問で本当に知りたいこと（深層心理）
       - answer_points: **募集職種のレベルに応じて、その役職に期待される回答ポイント**を3-4個

         #{LEVEL_EXAMPLES}

       - level: 求人票から判断した募集職種のレベル（日本語または英語で具体的に記述）
         例：「Junior Engineer」「Senior Engineer」「Engineering Manager」「Tech Lead」「Staff Engineer」など

    2. reverse_questions: **募集職種のレベルと理想的な人物像に合わせた逆質問のアドバイス**（2-3行の文章）

         #{REVERSE_QUESTION_EXAMPLES}

    3. tech_checklist: 面接前の確認項目5-8個（文字列の配列）

    ※求人内容に特化した具体的な内容にする
    ※answer_pointsとreverse_questionsは必ず募集職種のレベル（Junior/Senior/EM/Tech Leadなど）を考慮して記述すること
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
