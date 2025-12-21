class CasualInterviewNoteService
  class GenerationError < StandardError; end

  def self.call(history)
    new(history).call
  end

  def initialize(history)
    @history = history
  end

  def call
    validate_inputs!

    note_result = generate_with_ai
    save_note_results(note_result)

    @history.reload
  end

  private

  def validate_inputs!
    raise GenerationError, "対策ノートが指定されていません" if @history.nil?
    raise GenerationError, "会社名が入力されていません" if @history.company_name.blank?
  end

  def generate_with_ai
    client = OpenAI::Client.new
    response = client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: build_note_prompt }
      ],
      temperature: 0.7
    )

    parse_note_response(response)
  end

  def system_prompt
    <<~PROMPT
      あなたは転職エージェントとして10年以上の経験を持つキャリアアドバイザーです。
      カジュアル面談に臨む求職者のために、企業情報を調査・整理してノートを作成します。

      【重要な調査方針】
      - あなたの学習データに含まれる確実な情報のみを記載してください
      - 知らない企業や不確実な情報は、絶対に推測しないでください
      - 情報が不明な場合は必ず「情報なし」と明記してください
      - 競合企業名などは、確実に知っている場合のみ具体名を挙げてください
      - 知らない場合は「株式会社A」のような架空の名前ではなく、空配列にするか「情報なし」と記載してください
      - ニュースや日付情報も、確実な情報がない場合は空配列にしてください
      - 推測や憶測は避け、事実に基づいた情報のみを記載してください
      - カジュアル面談で聞くべき質問のヒントも含めてください

      出力は必ずJSON形式で行ってください。
    PROMPT
  end

  def build_note_prompt
    job_info = @history.job_description.presence || "（求人情報なし）"

    <<~PROMPT
      以下の企業について、カジュアル面談の準備ノートを作成してください。

      【企業名】
      #{@history.company_name}

      【求人情報（参考）】
      #{job_info.truncate(2000)}

      【出力形式（JSON）】
      {
        "business_overview": {
          "description": "事業内容の概要",
          "products": ["主要プロダクト1", "主要プロダクト2"],
          "target_market": "ターゲット市場"
        },
        "company_phase": {
          "stage": "スタートアップ/成長期/成熟期など",
          "description": "現在のフェーズの詳細説明",
          "funding_info": "資金調達状況（あれば）"
        },
        "business_model": {
          "revenue_model": "収益モデルの説明",
          "key_strengths": ["ビジネスモデルの強み1", "強み2"]
        },
        "organization_culture": {
          "culture_description": "組織カルチャーの特徴",
          "work_style": "働き方の特徴（リモート可否など）",
          "values": ["企業の価値観1", "価値観2"]
        },
        "recent_news": [
          {"date": "YYYY-MM", "title": "ニュースタイトル1", "summary": "概要"},
          {"date": "YYYY-MM", "title": "ニュースタイトル2", "summary": "概要"}
        ],
        "competitive_analysis": {
          "competitors": ["競合企業1", "競合企業2"],
          "strengths": ["同業他社と比べた強み1", "強み2"],
          "weaknesses": ["同業他社と比べた弱み1", "弱み2"]
        },
        "interview_tips": {
          "questions_to_ask": [
            "カジュアル面談で聞くべき質問1",
            "カジュアル面談で聞くべき質問2",
            "カジュアル面談で聞くべき質問3"
          ],
          "points_to_research": [
            "さらに調べておくべきポイント1",
            "さらに調べておくべきポイント2"
          ]
        },
        "summary": "この企業の総括（2-3文）"
      }

      【注意事項】
      - 各セクションは簡潔かつ具体的に記載してください
      - 情報が見つからない項目は「情報なし」または空配列にしてください
      - recent_newsは確実な情報がある場合のみ記載（日付はYYYY-MM形式）
      - competitorsは具体的な企業名を知っている場合のみ記載し、知らない場合は空配列にしてください
      - 絶対に架空の企業名（「株式会社A」「株式会社B」など）を使わないでください
      - 推測や想像で情報を埋めないでください
      - JSONのみ出力（説明文不要）
    PROMPT
  end

  def parse_note_response(response)
    content = response.choices&.first&.message&.content
    raise GenerationError, "AIからの応答が空です" if content.blank?

    json_string = content.gsub(/\A```json|```|\A```|\Z```/m, "").strip
    parsed = JSON.parse(json_string, symbolize_names: true)

    validate_parsed_result!(parsed)
    parsed
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parse error: #{e.message}\nContent: #{content}"
    raise GenerationError, "ノート生成結果の解析に失敗しました"
  end

  def validate_parsed_result!(parsed)
    raise GenerationError, "ビジネス概要が含まれていません" unless parsed[:business_overview]
    raise GenerationError, "企業フェーズ情報が含まれていません" unless parsed[:company_phase]
  end

  def save_note_results(result)
    notes_data = {
      business_overview: result[:business_overview],
      company_phase: result[:company_phase],
      business_model: result[:business_model],
      organization_culture: result[:organization_culture],
      recent_news: Array(result[:recent_news]),
      competitive_analysis: result[:competitive_analysis],
      interview_tips: result[:interview_tips],
      summary: result[:summary],
      generated_at: Time.current.iso8601
    }

    Rails.logger.info "Saving casual_interview_notes: #{notes_data.inspect}"

    @history.update!(casual_interview_notes: notes_data)

    Rails.logger.info "After save, casual_interview_notes: #{@history.reload.casual_interview_notes.inspect}"
  end
end
