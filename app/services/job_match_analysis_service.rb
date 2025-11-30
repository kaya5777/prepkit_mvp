class JobMatchAnalysisService
  class AnalysisError < StandardError; end

  # 合格可能性のランク定義
  RANK_DEFINITIONS = {
    "S" => { range: 90..100, label: "非常に高い", description: "経歴と求人要件が非常にマッチしています" },
    "A" => { range: 80..89, label: "高い", description: "多くの要件を満たしており、好印象が期待できます" },
    "B" => { range: 70..79, label: "やや高い", description: "基本的な要件を満たしています" },
    "C" => { range: 60..69, label: "普通", description: "一部の要件にギャップがあります" },
    "D" => { range: 0..59, label: "要改善", description: "アピールポイントの強化が必要です" }
  }.freeze

  def self.call(history, resume)
    new(history, resume).call
  end

  def initialize(history, resume)
    @history = history
    @resume = resume
  end

  def call
    validate_inputs!

    analysis_result = analyze_with_ai
    save_analysis_results(analysis_result)

    @history.reload
  end

  private

  def validate_inputs!
    raise AnalysisError, "対策ノートが指定されていません" if @history.nil?
    raise AnalysisError, "職務経歴書が指定されていません" if @resume.nil?
    raise AnalysisError, "職務経歴書が分析されていません" unless @resume.analyzed?
  end

  def analyze_with_ai
    client = OpenAI::Client.new
    response = client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: build_analysis_prompt }
      ],
      temperature: 0.5
    )

    parse_analysis_response(response)
  end

  def system_prompt
    <<~PROMPT
      あなたは転職エージェントとして10年以上の経験を持つキャリアアドバイザーです。
      求職者の職務経歴と求人要件を照合し、マッチ度を分析します。

      【重要な評価基準】
      1. **業種・職種の一致を最優先で評価してください**
      2. 異業種・異職種の場合は、たとえスキルが優れていても大幅に減点してください
      3. 例: エンジニア求人に営業職経歴 → 最高でもC判定（60-69点）
      4. 例: 営業職求人にエンジニア経歴 → 最高でもC判定（60-69点）
      5. 同業種・同職種でも経験年数や具体的なスキルマッチを厳しく評価してください

      【評価姿勢】
      - 容赦なく正直に、曖昧な表現を避けて評価してください
      - 「やや不足」「少し足りない」などの遠回しな表現ではなく、「不足している」「足りない」と明確に伝えてください
      - 過度に肯定的な言い回しは避け、改善が必要な点は率直に指摘してください
      - ユーザーの成長のために、真実を和らげず直接的で理性的なフィードバックを提供してください

      分析は客観的かつ建設的に行い、改善可能なアドバイスを提供してください。
      出力は必ずJSON形式で行ってください。
    PROMPT
  end

  def build_analysis_prompt
    job_info = build_job_info
    resume_info = @resume.raw_text.to_s.truncate(4000)

    <<~PROMPT
      以下の求人情報と職務経歴書を照合し、マッチ度を分析してください。

      【求人情報】
      企業名: #{@history.company_name}
      求人内容:
      #{job_info}

      【職務経歴書】
      #{resume_info}

      【出力形式（JSON）】
      {
        "match_score": 75,
        "match_rank": "B",
        "matching_points": [
          {"requirement": "求人の要件", "experience": "候補者の該当経験", "strength": "強み/アピールポイント"}
        ],
        "gap_points": [
          {"requirement": "求人の要件", "gap": "不足している点", "suggestion": "補う方法のアドバイス"}
        ],
        "appeal_suggestions": [
          "面接でアピールすべきポイント1",
          "面接でアピールすべきポイント2"
        ],
        "interview_tips": [
          "この求人特有の面接対策アドバイス1",
          "この求人特有の面接対策アドバイス2"
        ],
        "summary": "総合評価を2-3文で"
      }

      【注意事項】
      - match_scoreは0-100の整数（90以上:S, 80-89:A, 70-79:B, 60-69:C, 59以下:D）
      - match_rankはS/A/B/C/Dのいずれか
      - matching_pointsは2-4個
      - gap_pointsは1-3個（ない場合は空配列）
      - appeal_suggestionsは2-3個
      - interview_tipsは2-3個
      - JSONのみ出力（説明文不要）

      【スコアリング基準（厳格に適用）】
      重要: スコアは容赦なく厳格に採点してください。努力や可能性を考慮して甘く採点しないでください。

      - 業種・職種が完全に異なる場合: 基本50-60点、最高でも65点まで（C判定またはD判定）
      - 業種は同じだが職種が異なる場合: 基本60-70点、最高でも75点まで（B判定またはC判定）
      - 業種・職種が同じで経験不足の場合: 基本65-75点（B判定またはC判定）
      - 業種・職種が同じで十分な経験がある場合: 80-89点（A判定）
      - 業種・職種が同じで経験豊富かつスキル完全一致: 90点以上（S判定）

      判定時の注意:
      - 「努力している」「ポテンシャルがある」などの理由でスコアを上げないでください
      - 現時点での客観的なマッチ度のみを評価してください
      - 迷ったら低い方のスコアを選択してください
    PROMPT
  end

  def build_job_info
    # Historyから求人情報を構築
    info = []
    info << @history.job_description if @history.job_description.present?

    # 生成された面接情報からも抽出を試みる
    if @history.content.present?
      begin
        parsed = JSON.parse(@history.content)
        if parsed.is_a?(Hash) && parsed["questions"]
          info << "【想定質問】"
          parsed["questions"].first(3).each do |q|
            info << "- #{q['question']}" if q.is_a?(Hash) && q["question"]
          end
        end
      rescue JSON::ParserError
        # 無視
      end
    end

    info.join("\n").truncate(3000)
  end

  def parse_analysis_response(response)
    content = response.choices&.first&.message&.content
    raise AnalysisError, "AIからの応答が空です" if content.blank?

    json_string = content.gsub(/\A```json|```|\A```|\Z```/m, "").strip
    parsed = JSON.parse(json_string, symbolize_names: true)

    validate_parsed_result!(parsed)
    parsed
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parse error: #{e.message}\nContent: #{content}"
    raise AnalysisError, "分析結果の解析に失敗しました"
  end

  def validate_parsed_result!(parsed)
    raise AnalysisError, "スコアが含まれていません" unless parsed[:match_score]
    raise AnalysisError, "ランクが含まれていません" unless parsed[:match_rank]
  end

  def save_analysis_results(result)
    @history.update!(
      match_score: result[:match_score].to_i.clamp(0, 100),
      match_rank: result[:match_rank],
      match_analysis: {
        matching_points: Array(result[:matching_points]),
        gap_points: Array(result[:gap_points]),
        appeal_suggestions: Array(result[:appeal_suggestions]),
        interview_tips: Array(result[:interview_tips]),
        summary: result[:summary],
        analyzed_at: Time.current.iso8601,
        resume_id: @resume.id
      }
    )
  end

  # ランク情報を取得するヘルパー
  def self.rank_info(rank)
    RANK_DEFINITIONS[rank] || RANK_DEFINITIONS["D"]
  end
end
