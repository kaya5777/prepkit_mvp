# 複数のLLMプロバイダーで並列実行するヘルパー
# OpenAI と Gemini の両方で処理を実行し、両方の結果を返す
class DualLlmExecutor
  # 両方のプロバイダーで並列実行
  # @param block [Proc] プロバイダー名を受け取って結果を返すブロック
  # @return [Hash] { openai: result, gemini: result, openai_error: error, gemini_error: error }
  def self.execute_both(&block)
    results = {}
    threads = []

    # OpenAI で実行
    threads << Thread.new do
      begin
        results[:openai] = block.call("openai")
        results[:openai_error] = nil
      rescue => e
        Rails.logger.error "OpenAI execution failed: #{e.message}"
        results[:openai] = nil
        results[:openai_error] = e
      end
    end

    # Gemini で実行
    threads << Thread.new do
      begin
        results[:gemini] = block.call("gemini")
        results[:gemini_error] = nil
      rescue => e
        Rails.logger.error "Gemini execution failed: #{e.message}"
        results[:gemini] = nil
        results[:gemini_error] = e
      end
    end

    # 両方の完了を待つ
    threads.each(&:join)

    results
  end

  # 少なくとも1つが成功していることを確認
  def self.validate_results!(results)
    if results[:openai].nil? && results[:gemini].nil?
      openai_error = results[:openai_error]&.message || "Unknown error"
      gemini_error = results[:gemini_error]&.message || "Unknown error"
      raise StandardError, "Both LLM providers failed. OpenAI: #{openai_error}, Gemini: #{gemini_error}"
    end
  end
end
