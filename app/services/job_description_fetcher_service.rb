require "open-uri"
require "nokogiri"

class JobDescriptionFetcherService
  class FetchError < StandardError; end

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    validate_url!
    fetch_and_parse
  rescue OpenURI::HTTPError => e
    raise FetchError, "URLからの取得に失敗しました: #{e.message}"
  rescue SocketError => e
    raise FetchError, "URLに接続できません: #{e.message}"
  rescue StandardError => e
    raise FetchError, "予期しないエラーが発生しました: #{e.message}"
  end

  private

  def validate_url!
    uri = URI.parse(@url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      raise FetchError, "有効なURLを入力してください"
    end
  rescue URI::InvalidURIError
    raise FetchError, "無効なURL形式です"
  end

  def fetch_and_parse
    html = URI.open(@url, read_timeout: 10).read
    doc = Nokogiri::HTML(html)

    # Remove script, style, nav, footer, header tags
    doc.css("script, style, nav, footer, header, aside, .nav, .footer, .header, .sidebar").remove

    # Try to find job description content using common selectors
    content = extract_job_content(doc)

    # Clean up whitespace
    cleaned_content = content.gsub(/\s+/, " ").strip

    # OpenAI APIが利用可能で、コンテンツが長すぎる場合はAIで求人情報を抽出
    if ENV["OPENAI_API_KEY"].present? && cleaned_content.length > 3000
      extract_with_ai(cleaned_content)
    else
      cleaned_content
    end
  end

  def extract_job_content(doc)
    # 求人情報を含む可能性の高いセレクタを優先順位順に試す
    selectors = [
      # 求人サイト特有のセレクタ
      "article.job-description",
      "div.job-description",
      "section.job-description",
      "div[class*='job-detail']",
      "div[class*='job_detail']",
      "section[class*='job-detail']",
      "div[id*='job-description']",
      "div[id*='jobDescription']",

      # 一般的なコンテンツセレクタ
      "main article",
      "article",
      "main",
      "[role='main']",
      "div.content",
      "div#content",

      # 最終的なフォールバック
      "body"
    ]

    selectors.each do |selector|
      elements = doc.css(selector)
      next if elements.empty?

      # 最も長いコンテンツを持つ要素を選択（求人情報は通常長い）
      element = elements.max_by { |e| e.text.length }
      return element.text if element && element.text.length > 100
    end

    # どのセレクタでも見つからない場合はbody全体を返す
    doc.css("body").text
  end

  def extract_with_ai(content)
    # コンテンツが長すぎる場合は最初の5000文字に制限
    truncated_content = content[0...5000]

    client = OpenAI::Client.new
    response = client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: "あなたは求人情報の抽出専門家です。Webページから求人情報のみを抽出してください。"
        },
        {
          role: "user",
          content: <<~PROMPT
          以下のWebページテキストから、求人情報に関する部分だけを抽出してください。
          ナビゲーション、広告、その他の不要な情報は除外してください。

          【抽出する情報】
          - 募集職種
          - 業務内容
          - 必須スキル・歓迎スキル
          - 求める人物像
          - 勤務地・条件
          - 企業情報（簡潔に）

          【Webページテキスト】
          #{truncated_content}

          ※求人情報のみを抽出して返してください。説明文は不要です。
          PROMPT
        }
      ],
      temperature: 0.3,
      max_tokens: 2000
    )

    response.dig("choices", 0, "message", "content") || content
  rescue StandardError => e
    Rails.logger.warn "AI抽出に失敗しました: #{e.message}。元のコンテンツを返します。"
    content
  end
end
