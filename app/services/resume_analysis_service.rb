class ResumeAnalysisService
  class AnalysisError < StandardError; end

  CATEGORIES = {
    structure: {
      name: "構成",
      description: "職務経歴書の構成・レイアウト・セクション分けの適切さ"
    },
    content: {
      name: "内容",
      description: "経歴・実績の具体性、数値化、アピールポイントの明確さ"
    },
    expression: {
      name: "表現",
      description: "文章の読みやすさ、専門用語の適切な使用、誤字脱字"
    },
    layout: {
      name: "見やすさ",
      description: "視覚的な読みやすさ、情報の整理、余白の使い方"
    }
  }.freeze

  def self.call(resume)
    new(resume).call
  end

  def initialize(resume)
    @resume = resume
  end

  def call
    validate_resume!

    @resume.update!(status: "analyzing")

    begin
      # テキスト抽出
      raw_text = extract_text
      @resume.update!(raw_text: raw_text)

      # AI分析
      analysis_result = analyze_with_ai(raw_text)

      # 結果を保存
      save_analysis_results(analysis_result)

      # 要約を更新
      @resume.update!(
        summary: analysis_result[:summary],
        status: "analyzed",
        analyzed_at: Time.current
      )

      @resume.reload
    rescue => e
      @resume.update!(status: "error")
      raise AnalysisError, e.message
    end
  end

  private

  def validate_resume!
    raise AnalysisError, "ファイルがアップロードされていません" unless @resume.original_file.attached?
  end

  def extract_text
    ResumeTextExtractorService.new(@resume).call
  rescue ResumeTextExtractorService::ExtractionError => e
    raise AnalysisError, e.message
  end

  def analyze_with_ai(raw_text)
    client = OpenAI::Client.new
    response = client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: build_analysis_prompt(raw_text) }
      ],
      temperature: 0.5
    )

    parse_analysis_response(response)
  end

  def system_prompt
    <<~PROMPT
      あなたは転職エージェントとして10年以上の経験を持つ職務経歴書の添削専門家です。
      日本の採用市場に精通しており、採用担当者の視点から職務経歴書を評価できます。

      【評価姿勢】
      - 容赦なく正直に、厳格に評価してください
      - 内容が薄い、具体性がない、数値がない場合は大幅に減点してください
      - 「やや不足」「少し足りない」などの遠回しな表現ではなく、「不足している」「足りない」と明確に伝えてください
      - 過度に肯定的な言い回しは避け、改善が必要な点は率直に指摘してください
      - 努力や可能性ではなく、現時点の客観的な品質のみを評価してください
      - 迷ったら低い方のスコアを選択してください

      建設的かつ具体的なフィードバックを提供してください。
      出力は必ずJSON形式で行ってください。
    PROMPT
  end

  def build_analysis_prompt(raw_text)
    <<~PROMPT
      以下の職務経歴書を分析し、改善点と良い点を指摘してください。

      【職務経歴書の内容】
      #{raw_text.truncate(6000)}

      【評価カテゴリ】
      1. 構成（structure）: #{CATEGORIES[:structure][:description]}
      2. 内容（content）: #{CATEGORIES[:content][:description]}
      3. 表現（expression）: #{CATEGORIES[:expression][:description]}
      4. 見やすさ（layout）: #{CATEGORIES[:layout][:description]}

      【出力形式（JSON）】
      {
        "summary": "この職務経歴書の概要を2-3文で記述",
        "categories": {
          "structure": {
            "score": 75,
            "good_points": ["良い点1", "良い点2"],
            "issues": ["問題点1", "問題点2"],
            "suggestions": ["具体的な改善提案1", "具体的な改善提案2"]
          },
          "content": {
            "score": 70,
            "good_points": ["良い点1", "良い点2"],
            "issues": ["問題点1", "問題点2"],
            "suggestions": ["具体的な改善提案1", "具体的な改善提案2"]
          },
          "expression": {
            "score": 80,
            "good_points": ["良い点1"],
            "issues": ["問題点1"],
            "suggestions": ["具体的な改善提案1"]
          },
          "layout": {
            "score": 65,
            "good_points": ["良い点1"],
            "issues": ["問題点1"],
            "suggestions": ["具体的な改善提案1"]
          }
        }
      }

      【注意事項】
      - scoreは0-100の整数
      - 各カテゴリのgood_points, issues, suggestionsはそれぞれ1-3個
      - suggestionsは具体的で実践可能な内容にする
      - JSONのみ出力（説明文不要）

      【スコアリング基準（厳格に適用）】
      重要: スコアは容赦なく厳格に採点してください。内容が不十分な場合は遠慮なく低得点をつけてください。

      ■ 全体的な基準
      - 内容がほぼ空、またはテンプレートのみ: 0-20点（最高でも25点まで）
      - 最低限の情報のみ（会社名・期間だけ、具体性なし）: 20-40点（最高でも45点まで）
      - 基本情報はあるが具体性・数値が不足: 40-60点
      - 具体的な記述があるが改善の余地あり: 60-75点
      - 十分な具体性と数値、優れた構成: 75-85点
      - 採用担当者が即座に評価できる完璧な内容: 85-100点

      ■ カテゴリ別の減点ポイント

      【構成（structure）】
      - セクション分けが不明瞭: -15点
      - 時系列が逆順になっていない: -10点
      - 職歴の期間が不明確: -10点
      - 見出しがない、または不適切: -10点

      【内容（content）】
      - 具体的な業務内容の記述なし: -20点
      - 数値での実績表現が全くない: -15点
      - 担当した役割・責任が不明確: -15点
      - 使用技術・ツールの記載なし（技術職の場合）: -10点
      - プロジェクト規模が不明: -10点

      【表現（expression）】
      - 誤字脱字が複数ある: -10点
      - 「〜など」「〜等」の曖昧表現が多用されている: -10点
      - 箇条書きではなく長文で読みにくい: -10点
      - 専門用語の説明がない（または逆に専門用語を使っていない）: -5点

      【見やすさ（layout）】
      - フォントサイズがバラバラ: -10点
      - 余白が不適切（詰め込みすぎ or スカスカ）: -10点
      - 箇条書きの階層が不明瞭: -5点
      - 重要な情報が埋もれている: -10点

      判定時の注意:
      - 各カテゴリで減点ポイントを確認し、該当する項目は必ず減点してください
      - 「頑張っている」「ポテンシャルがある」などの理由でスコアを上げないでください
      - 現時点での客観的な品質のみを評価してください
      - 迷ったら低い方のスコアを選択してください
      - 内容が薄い場合は、全カテゴリで50点未満にすることを躊躇しないでください
    PROMPT
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
    raise AnalysisError, "概要が含まれていません" unless parsed[:summary]
    raise AnalysisError, "カテゴリ分析が含まれていません" unless parsed[:categories]

    CATEGORIES.keys.each do |category|
      cat_key = category.to_sym
      unless parsed[:categories][cat_key]
        raise AnalysisError, "#{CATEGORIES[category][:name]}の分析が含まれていません"
      end
    end
  end

  def save_analysis_results(analysis_result)
    # 既存の分析結果を削除
    @resume.resume_analyses.destroy_all

    # カテゴリ別に保存
    analysis_result[:categories].each do |category, data|
      @resume.resume_analyses.create!(
        category: category.to_s,
        score: data[:score].to_i.clamp(0, 100),
        feedback: {
          good_points: Array(data[:good_points]),
          issues: Array(data[:issues]),
          suggestions: Array(data[:suggestions]),
          examples: []
        },
        improved_text: nil
      )
    end
  end
end
