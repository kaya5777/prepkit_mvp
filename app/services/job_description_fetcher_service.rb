require "open-uri"
require "nokogiri"

class JobDescriptionFetcherService
  class FetchError < StandardError; end

  READ_TIMEOUT = 10
  MAX_CONTENT_LENGTH = 3000
  AI_CONTENT_LIMIT = 5000
  MIN_CONTENT_LENGTH = 100

  JOB_SELECTORS = [
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
  ].freeze

  REMOVABLE_ELEMENTS = "script, style, nav, footer, header, aside, .nav, .footer, .header, .sidebar"

  AI_EXTRACTION_PROMPT = <<~PROMPT.freeze
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
    %{content}

    ※求人情報のみを抽出して返してください。説明文は不要です。
  PROMPT

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
    html = URI.open(@url, read_timeout: READ_TIMEOUT).read
    doc = Nokogiri::HTML(html)

    remove_unnecessary_elements(doc)
    content = extract_job_content(doc)
    cleaned_content = clean_whitespace(content)

    should_use_ai?(cleaned_content) ? extract_with_ai(cleaned_content) : cleaned_content
  end

  def remove_unnecessary_elements(doc)
    doc.css(REMOVABLE_ELEMENTS).remove
  end

  def clean_whitespace(content)
    content.gsub(/\s+/, " ").strip
  end

  def should_use_ai?(content)
    ENV["OPENAI_API_KEY"].present? && content.length > MAX_CONTENT_LENGTH
  end

  def extract_job_content(doc)
    JOB_SELECTORS.each do |selector|
      content = find_longest_content(doc, selector)
      return content if content
    end

    # どのセレクタでも見つからない場合はbody全体を返す
    doc.css("body").text
  end

  def find_longest_content(doc, selector)
    elements = doc.css(selector)
    return nil if elements.empty?

    element = elements.max_by { |e| e.text.length }
    element.text if element && element.text.length > MIN_CONTENT_LENGTH
  end

  def extract_with_ai(content)
    truncated_content = content[0...AI_CONTENT_LIMIT]

    response = call_openai_extraction(truncated_content)
    response.dig("choices", 0, "message", "content") || content
  rescue StandardError => e
    Rails.logger.warn "AI抽出に失敗しました: #{e.message}。元のコンテンツを返します。"
    content
  end

  def call_openai_extraction(content)
    client = OpenAI::Client.new
    client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: ai_extraction_messages(content),
      temperature: 0.3,
      max_tokens: 2000
    )
  end

  def ai_extraction_messages(content)
    [
      {
        role: "system",
        content: "あなたは求人情報の抽出専門家です。Webページから求人情報のみを抽出してください。"
      },
      {
        role: "user",
        content: format(AI_EXTRACTION_PROMPT, content: content)
      }
    ]
  end
end
