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

    # questionsが正しい形式（オブジェクトの配列）であることを確認
    if parsed[:questions].is_a?(Array)
      parsed[:questions] = parsed[:questions].map do |q|
        if q.is_a?(Hash)
          # 新形式: {question, intent, answer_points, level}
          {
            question: q[:question] || q["question"],
            intent: q[:intent] || q["intent"] || "",
            answer_points: q[:answer_points] || q["answer_points"] || [],
            level: q[:level] || q["level"] || ""
          }
        else
          # 旧形式の文字列の場合は変換
          {
            question: q.to_s,
            intent: "",
            answer_points: [],
            level: ""
          }
        end
      end
    end

    # reverse_questionsが文字列であることを確認（新形式）または配列から文字列に変換（旧形式との互換性）
    if parsed[:reverse_questions].is_a?(Array)
      # 旧形式: 配列の場合は改行で結合
      parsed[:reverse_questions] = parsed[:reverse_questions].map do |q|
        q.is_a?(Hash) ? (q[:question] || q["question"] || q.to_s) : q.to_s
      end.join("\n")
    elsif !parsed[:reverse_questions].is_a?(String)
      parsed[:reverse_questions] = ""
    end

    # tech_checklistが文字列の配列であることを確認
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
    出力形式: {"questions":[],"reverse_questions":[],"tech_checklist":[]}
    PROMPT
  end

  def build_prompt
    <<~PROMPT
    求人票を分析し、面接対策情報を以下の形式のJSONで生成してください。

    【求人票】
    #{@job_description}

    【出力形式】
    {
      "questions": [
        {
          "question": "質問文",
          "intent": "この質問で面接官が知りたいこと（1-2文）",
          "answer_points": ["回答のポイント1", "回答のポイント2", "回答のポイント3"],
          "level": "募集職種のレベル（例：Junior Engineer, Mid-level Engineer, Senior Engineer, Tech Lead, Engineering Manager, など）"
        }
      ],
      "reverse_questions": "逆質問のアドバイス（2-3行の文章）",
      "tech_checklist": ["確認項目1", "確認項目2", ...]
    }

    【重要な指示】

    1. questions: 技術質問3個+行動面接質問2個の計5個
       - question: 質問文
       - intent: 面接官がこの質問で本当に知りたいこと（深層心理）
       - answer_points: **募集職種のレベルに応じて、その役職に期待される回答ポイント**を3-4個

         例：
         - 「Junior Engineer」募集の場合
           → 基礎知識の理解度、学習意欲、成長ポテンシャルを示すポイント

         - 「Senior Engineer」募集の場合
           → 実装力だけでなく、設計判断、技術選定の根拠、パフォーマンス最適化の経験など

         - 「Engineering Manager (EM)」募集の場合
           → チームマネジメント経験、1on1やパフォーマンス評価の手法、技術的意思決定とビジネス目標のバランス、採用・育成の実績など

         - 「Tech Lead」募集の場合
           → アーキテクチャ設計の主導経験、技術的負債の解消戦略、メンバーのコードレビューやメンタリング、ステークホルダーとの技術コミュニケーションなど

       - level: 求人票から判断した募集職種のレベル（日本語または英語で具体的に記述）
         例：「Junior Engineer」「Senior Engineer」「Engineering Manager」「Tech Lead」「Staff Engineer」など

    2. reverse_questions: **募集職種のレベルと理想的な人物像に合わせた逆質問のアドバイス**（2-3行の文章）

         例：
         - Junior Engineer募集の場合
           「技術スタックの学習機会や、メンターシップ制度の有無について確認しましょう。成長環境として、コードレビューの文化やペアプログラミングの頻度、オンボーディングプロセスについて聞くことで、学習意欲をアピールできます。」

         - Senior Engineer募集の場合
           「技術的意思決定のプロセスや、アーキテクチャ設計への関与度について確認しましょう。技術的負債への取り組み方や、新技術導入の判断基準、チーム内での技術リーダーシップの期待値について聞くことで、シニアとしての視点をアピールできます。」

         - Engineering Manager募集の場合
           「チームの構成や評価制度、1on1の頻度と内容について確認しましょう。採用プロセスへの関与度、キャリア開発の支援体制、エンジニアリングとビジネス目標のバランスをどう取っているかを聞くことで、マネジメント経験と関心をアピールできます。」

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
