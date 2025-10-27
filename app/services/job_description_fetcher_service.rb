require 'open-uri'
require 'nokogiri'

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

    # Remove script and style tags
    doc.css('script, style').remove

    # Extract text content
    text = doc.css('body').text

    # Clean up whitespace
    text.gsub(/\s+/, ' ').strip
  end
end
