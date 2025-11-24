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
      建設的かつ具体的なフィードバックを提供してください。
      出力は必ずJSON形式で行ってください。
    PROMPT
  end

  def build_analysis_prompt(raw_text)
    <<~PROMPT
      以下の職務経歴書を分析し、改善点と良い点を指摘してください。

      【職務経歴書の内容】
      #{raw_text.truncate(8000)}

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
            "suggestions": ["具体的な改善提案1", "具体的な改善提案2"],
            "examples": [
              {"before": "改善前の文章（実際の職務経歴書から抜粋）", "after": "改善後の文章（具体的に書き換えた例）"},
              {"before": "改善前の文章2", "after": "改善後の文章2"}
            ]
          },
          "content": {
            "score": 70,
            "good_points": ["良い点1", "良い点2"],
            "issues": ["問題点1", "問題点2"],
            "suggestions": ["具体的な改善提案1", "具体的な改善提案2"],
            "examples": [
              {"before": "改善前の文章", "after": "改善後の文章"}
            ]
          },
          "expression": {
            "score": 80,
            "good_points": ["良い点1"],
            "issues": ["問題点1"],
            "suggestions": ["具体的な改善提案1"],
            "examples": [
              {"before": "改善前の文章", "after": "改善後の文章"}
            ]
          },
          "layout": {
            "score": 65,
            "good_points": ["良い点1"],
            "issues": ["問題点1"],
            "suggestions": ["具体的な改善提案1"],
            "examples": [
              {"before": "改善前の文章", "after": "改善後の文章"}
            ]
          }
        },
        "improved_text": "改善後の職務経歴書の全文（元の形式を維持しつつ改善を適用）"
      }

      【注意事項】
      - scoreは0-100の整数
      - 各カテゴリのgood_points, issues, suggestionsはそれぞれ1-3個
      - suggestionsは具体的で実践可能な内容にする
      - examplesは各カテゴリで1-2個、実際の職務経歴書から抜粋した文章をbeforeに、改善例をafterに記載
      - examplesのbeforeは実際の職務経歴書にある文言を使用し、afterは具体的に改善した例を示す
      - improved_textは元の職務経歴書を改善したバージョン全文
      - JSONのみ出力（説明文不要）
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
          examples: Array(data[:examples])
        },
        improved_text: analysis_result[:improved_text]
      )
    end
  end
end
