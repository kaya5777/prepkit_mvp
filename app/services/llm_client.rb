# LLMクライアントの抽象化レイヤー
# OpenAI と Gemini を統一的なインターフェースで扱う
#
# 使い方:
#   client = LlmClient.new
#   response = client.chat(
#     system: "あなたはアシスタントです",
#     user: "こんにちは",
#     temperature: 0.5
#   )
#   content = response.content
#
# 環境変数での切り替え:
#   LLM_PROVIDER=openai    # OpenAI を使用（デフォルト）
#   LLM_PROVIDER=gemini    # Gemini を使用

class LlmClient
  class LlmError < StandardError; end
  class ConfigurationError < LlmError; end

  # レスポンスオブジェクト（統一インターフェース）
  class Response
    attr_reader :content, :raw_response

    def initialize(content:, raw_response:)
      @content = content
      @raw_response = raw_response
    end
  end

  def initialize(provider: nil)
    @provider = provider || ENV.fetch("LLM_PROVIDER", "openai")
    @client = create_client
  end

  # チャット補完API呼び出し
  # @param system [String] システムプロンプト
  # @param user [String] ユーザープロンプト
  # @param model [String, nil] モデル名（nilの場合はデフォルト）
  # @param temperature [Float] 温度パラメータ（0.0-1.0）
  # @return [Response] レスポンスオブジェクト
  def chat(system:, user:, model: nil, temperature: 0.5)
    case @provider
    when "openai"
      chat_openai(system: system, user: user, model: model, temperature: temperature)
    when "gemini"
      chat_gemini(system: system, user: user, model: model, temperature: temperature)
    else
      raise ConfigurationError, "Unknown LLM provider: #{@provider}"
    end
  end

  # プロバイダー名を取得
  def provider
    @provider
  end

  # デフォルトモデル名を取得
  def default_model
    case @provider
    when "openai"
      "gpt-4o-mini"
    when "gemini"
      "gemini-2.5-flash"
    end
  end

  private

  def create_client
    case @provider
    when "openai"
      require "openai"
      OpenAI::Client.new
    when "gemini"
      require "gemini-ai"
      api_key = ENV["GEMINI_API_KEY"]
      raise ConfigurationError, "GEMINI_API_KEY is not set" if api_key.blank?
      Gemini.new(
        credentials: {
          service: "generative-language-api",
          api_key: api_key,
          version: "v1beta"
        },
        options: { model: default_model, server_sent_events: false }
      )
    else
      raise ConfigurationError, "Unknown LLM provider: #{@provider}"
    end
  end

  def chat_openai(system:, user:, model:, temperature:)
    model ||= default_model

    response = @client.chat.completions.create(
      model: model,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user }
      ],
      temperature: temperature
    )

    # OpenAI gemのレスポンスオブジェクトから内容を取得
    # オブジェクトの場合とHashの場合の両方に対応
    content = if response.respond_to?(:choices)
      response.choices&.first&.message&.content
    else
      response.dig("choices", 0, "message", "content")
    end

    raise LlmError, "Empty response from OpenAI" if content.blank?

    Response.new(content: content, raw_response: response)
  rescue => e
    raise LlmError, "OpenAI API error: #{e.message}"
  end

  def chat_gemini(system:, user:, model:, temperature:)
    model ||= default_model

    # Geminiではシステムプロンプトとユーザープロンプトを結合
    combined_prompt = "#{system}\n\n#{user}"

    response = @client.generate_content(
      {
        contents: { role: "user", parts: { text: combined_prompt } },
        generationConfig: { temperature: temperature }
      }
    )

    # レスポンスからテキストを抽出
    content = extract_gemini_content(response)
    raise LlmError, "Empty response from Gemini" if content.blank?

    Response.new(content: content, raw_response: response)
  rescue => e
    raise LlmError, "Gemini API error: #{e.message}"
  end

  def extract_gemini_content(response)
    # Geminiのレスポンスからテキストを抽出
    parts = []

    candidates = response.dig("candidates")
    return "" unless candidates

    candidates.each do |candidate|
      content = candidate.dig("content", "parts")
      next unless content

      content.each do |part|
        parts << part["text"] if part["text"]
      end
    end

    parts.join("")
  end
end
