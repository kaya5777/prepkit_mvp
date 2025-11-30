require 'rails_helper'

RSpec.describe JobDescriptionFetcherService do
  let(:valid_url) { "https://example.com/job/123" }
  let(:service) { described_class.new(valid_url) }

  describe ".call" do
    context "with valid URL and HTML" do
      let(:html_content) do
        <<~HTML
          <html>
            <head><title>求人情報</title></head>
            <body>
              <nav>ナビゲーション</nav>
              <main>
                <div class="job-description">
                  <h1>Railsエンジニア募集</h1>
                  <p>Ruby on Railsの開発経験3年以上</p>
                  <p>チーム開発の経験がある方</p>
                </div>
              </main>
              <footer>フッター</footer>
            </body>
          </html>
        HTML
      end

      before do
        stub_request(:get, valid_url)
          .to_return(status: 200, body: html_content, headers: { 'Content-Type' => 'text/html' })
      end

      it "fetches and parses job description" do
        result = described_class.call(valid_url)
        expect(result).to include("Railsエンジニア募集")
        expect(result).to include("Ruby on Rails")
      end

      it "removes navigation and footer" do
        result = described_class.call(valid_url)
        expect(result).not_to include("ナビゲーション")
        expect(result).not_to include("フッター")
      end
    end

    context "with invalid URL" do
      it "raises FetchError for non-HTTP URL" do
        expect {
          described_class.call("ftp://example.com")
        }.to raise_error(JobDescriptionFetcherService::FetchError, /有効なURLを入力してください/)
      end
    end

    context "when HTTP request fails" do
      before do
        stub_request(:get, valid_url).to_return(status: 404)
      end

      it "raises FetchError" do
        expect {
          described_class.call(valid_url)
        }.to raise_error(JobDescriptionFetcherService::FetchError, /URLからの取得に失敗しました/)
      end
    end

    context "when content is very long and AI extraction is available" do
      let(:long_html) do
        <<~HTML
          <html>
            <body>
              <div class="job-description">
                #{'長い求人情報テキスト ' * 500}
              </div>
            </body>
          </html>
        HTML
      end

      before do
        stub_request(:get, valid_url)
          .to_return(status: 200, body: long_html, headers: { 'Content-Type' => 'text/html' })

        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("test-key")
        allow(ENV).to receive(:[]).and_call_original

        fake_client = double("OpenAI::Client")
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)

        mock_response = {
          "choices" => [
            {
              "message" => {
                "content" => "抽出された求人情報"
              }
            }
          ]
        }
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_return(mock_response)
      end

      it "uses AI extraction for long content" do
        result = described_class.call(valid_url)
        expect(result).to eq("抽出された求人情報")
      end
    end
  end

  describe "private methods" do
    describe "#clean_whitespace" do
      it "normalizes whitespace" do
        content = "Line1   Line2\n\nLine3"
        result = service.send(:clean_whitespace, content)
        expect(result).to eq("Line1 Line2 Line3")
      end
    end

    describe "#should_use_ai?" do
      context "when API key is not present" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)
        end

        it "returns false" do
          result = service.send(:should_use_ai?, "a" * 5000)
          expect(result).to be false
        end
      end

      context "when content is short" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("key")
        end

        it "returns false" do
          result = service.send(:should_use_ai?, "short content")
          expect(result).to be false
        end
      end

      context "when API key is present and content is long" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("key")
        end

        it "returns true" do
          result = service.send(:should_use_ai?, "a" * 5000)
          expect(result).to be true
        end
      end
    end

    describe "#validate_url!" do
      it "accepts valid HTTP URL" do
        service = described_class.new("http://example.com")
        expect { service.send(:validate_url!) }.not_to raise_error
      end

      it "accepts valid HTTPS URL" do
        service = described_class.new("https://example.com")
        expect { service.send(:validate_url!) }.not_to raise_error
      end

      it "rejects FTP URL" do
        service = described_class.new("ftp://example.com")
        expect {
          service.send(:validate_url!)
        }.to raise_error(JobDescriptionFetcherService::FetchError, /有効なURLを入力してください/)
      end

      it "rejects malformed URL" do
        service = described_class.new("://invalid")
        expect {
          service.send(:validate_url!)
        }.to raise_error(JobDescriptionFetcherService::FetchError)
      end
    end
  end
end
