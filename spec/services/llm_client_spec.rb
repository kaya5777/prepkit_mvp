require "rails_helper"

RSpec.describe LlmClient, type: :service do
  describe "#initialize" do
    it "デフォルトでopenaiプロバイダーを使用" do
      allow(ENV).to receive(:fetch).with("LLM_PROVIDER", "openai").and_return("openai")
      client = described_class.new
      expect(client.provider).to eq("openai")
    end

    it "環境変数LLM_PROVIDERでプロバイダーを切り替え" do
      allow(ENV).to receive(:fetch).with("LLM_PROVIDER", "openai").and_return("gemini")
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")

      client = described_class.new
      expect(client.provider).to eq("gemini")
    end

    it "引数でプロバイダーを指定" do
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")

      client = described_class.new(provider: "gemini")
      expect(client.provider).to eq("gemini")
    end
  end

  describe "#default_model" do
    it "openaiの場合はgpt-4o-miniを返す" do
      client = described_class.new(provider: "openai")
      expect(client.default_model).to eq("gpt-4o-mini")
    end

    it "geminiの場合はgemini-2.5-flashを返す" do
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")

      client = described_class.new(provider: "gemini")
      expect(client.default_model).to eq("gemini-2.5-flash")
    end
  end

  describe "#chat" do
    context "OpenAIプロバイダー" do
      let(:client) { described_class.new(provider: "openai") }
      let(:mock_openai_client) { instance_double(OpenAI::Client) }
      let(:mock_chat) { double("chat") }
      let(:mock_completions) { double("completions") }

      before do
        allow(ENV).to receive(:fetch).with("LLM_PROVIDER", "openai").and_return("openai")
        allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
        allow(mock_openai_client).to receive(:chat).and_return(mock_chat)
        allow(mock_chat).to receive(:completions).and_return(mock_completions)
      end

      it "OpenAI APIを呼び出してレスポンスを返す" do
        mock_response = {
          "choices" => [
            {
              "message" => {
                "content" => "こんにちは"
              }
            }
          ]
        }

        allow(mock_completions).to receive(:create).and_return(mock_response)

        response = client.chat(
          system: "あなたはアシスタントです",
          user: "こんにちは",
          temperature: 0.5
        )

        expect(response).to be_a(LlmClient::Response)
        expect(response.content).to eq("こんにちは")
        expect(mock_completions).to have_received(:create).with(
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: "あなたはアシスタントです" },
            { role: "user", content: "こんにちは" }
          ],
          temperature: 0.5
        )
      end

      it "レスポンスが空の場合はエラーを発生" do
        mock_response = {
          "choices" => [
            {
              "message" => {
                "content" => nil
              }
            }
          ]
        }

        allow(mock_completions).to receive(:create).and_return(mock_response)

        expect {
          client.chat(
            system: "あなたはアシスタントです",
            user: "こんにちは",
            temperature: 0.5
          )
        }.to raise_error(LlmClient::LlmError, /Empty response/)
      end
    end

    context "Geminiプロバイダー" do
      let(:client) { described_class.new(provider: "gemini") }
      let(:mock_gemini_client) { double("Gemini") }

      before do
        allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
        allow(Gemini).to receive(:new).and_return(mock_gemini_client)
      end

      it "Gemini APIを呼び出してレスポンスを返す" do
        mock_response = {
          "candidates" => [
            {
              "content" => {
                "parts" => [
                  { "text" => "こんにちは" }
                ]
              }
            }
          ]
        }

        allow(mock_gemini_client).to receive(:generate_content).and_return(mock_response)

        response = client.chat(
          system: "あなたはアシスタントです",
          user: "こんにちは",
          temperature: 0.5
        )

        expect(response).to be_a(LlmClient::Response)
        expect(response.content).to eq("こんにちは")
      end

      it "APIキーが未設定の場合はエラーを発生" do
        allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)

        expect {
          described_class.new(provider: "gemini")
        }.to raise_error(LlmClient::ConfigurationError, /GEMINI_API_KEY is not set/)
      end
    end

    context "未知のプロバイダー" do
      it "エラーを発生" do
        expect {
          described_class.new(provider: "unknown")
        }.to raise_error(LlmClient::ConfigurationError, /Unknown LLM provider/)
      end
    end
  end
end
