require 'rails_helper'

RSpec.describe "Preparations", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /preparations" do
    context "when job_description is blank" do
      it "renders new with 422" do
        post preparations_path, params: { job_description: "" }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when OPENAI_API_KEY is missing" do
      it "renders error with helpful message" do
        stub_const('ENV', ENV.to_hash.merge('OPENAI_API_KEY' => ''))
        post preparations_path, params: { job_description: "foo" }
        # InterviewKitGeneratorService raises an error which becomes 422
        expect(response.status).to be >= 400
        expect(response.body).to include('API キーが設定されていません')
      end
    end

    context "when OpenAI returns valid JSON" do
      it "renders show successfully" do
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("test")
        allow(ENV).to receive(:[]).and_call_original
        fake_client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)
        message = double('message', content: {
          questions: [ "Q1", "Q2" ],
          star_answers: [
            { question: "Q1", situation: "具体的な状況説明", task: "課題の定義", action: "取った行動", result: "定量的な成果" }
          ],
          reverse_questions: [ "企業の技術スタックについて教えてください", "チームの開発プロセスはどうなっていますか" ],
          tech_checklist: [ "技術項目1を理解している", "技術項目2を説明できる" ]
        }.to_json)
        choice = double('choice', message: message)
        chat_completion = double('chat_completion', choices: [ choice ])
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_return(chat_completion)

        post preparations_path, params: { job_description: "Railsエンジニア募集" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "when URL is provided" do
      before do
        allow(JobDescriptionFetcherService).to receive(:call).and_return("Ruby on Railsエンジニア募集")
        allow(InterviewKitGeneratorService).to receive(:call).and_return({
          result: { stage_1: { questions: [] } },
          history: create(:history, user: user)
        })
      end

      it "fetches job description from URL" do
        post preparations_path, params: { job_description: "https://example.com/jobs/123" }
        expect(JobDescriptionFetcherService).to have_received(:call).with("https://example.com/jobs/123")
        expect(response).to have_http_status(:ok)
      end
    end

    context "when URL fetch fails" do
      before do
        allow(JobDescriptionFetcherService).to receive(:call).and_raise(
          JobDescriptionFetcherService::FetchError.new("URLから取得できませんでした")
        )
      end

      it "renders error message" do
        post preparations_path, params: { job_description: "https://example.com/jobs/123" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("URLから取得できませんでした")
      end
    end

    context "when URL fetch returns empty content" do
      before do
        allow(JobDescriptionFetcherService).to receive(:call).and_return("")
      end

      it "renders error message" do
        post preparations_path, params: { job_description: "https://example.com/jobs/123" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("URLから求人情報を取得できませんでした")
      end
    end

    context "when InterviewKitGeneratorService raises ContentBlankError" do
      before do
        allow(InterviewKitGeneratorService).to receive(:call).and_raise(
          InterviewKitGeneratorService::ContentBlankError.new("コンテンツが空です")
        )
      end

      it "renders error with service_unavailable status" do
        post preparations_path, params: { job_description: "test" }
        expect(response).to have_http_status(:service_unavailable)
        expect(response.body).to include("コンテンツが空です")
      end
    end

    context "when InterviewKitGeneratorService raises ParseError" do
      before do
        allow(InterviewKitGeneratorService).to receive(:call).and_raise(
          InterviewKitGeneratorService::ParseError.new("JSONパースエラー")
        )
      end

      it "renders error with unprocessable_content status" do
        post preparations_path, params: { job_description: "test" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("JSONパースエラー")
      end
    end

    context "when InterviewKitGeneratorService raises AuthenticationError" do
      before do
        allow(InterviewKitGeneratorService).to receive(:call).and_raise(
          InterviewKitGeneratorService::AuthenticationError.new("認証エラー")
        )
      end

      it "renders error with service_unavailable status" do
        post preparations_path, params: { job_description: "test" }
        expect(response).to have_http_status(:service_unavailable)
        expect(response.body).to include("認証エラー")
      end
    end

    context "when unexpected StandardError occurs" do
      before do
        allow(InterviewKitGeneratorService).to receive(:call).and_raise(
          StandardError.new("予期しないエラー")
        )
      end

      it "renders generic error with internal_server_error status" do
        post preparations_path, params: { job_description: "test" }
        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to include("エラーが発生しました")
      end
    end

    context "with company_name parameter" do
      before do
        allow(InterviewKitGeneratorService).to receive(:call).and_return({
          result: { stage_1: { questions: [] } },
          history: create(:history, user: user, company_name: "テスト企業")
        })
      end

      it "passes company_name to service" do
        post preparations_path, params: { job_description: "test", company_name: "テスト企業" }
        expect(InterviewKitGeneratorService).to have_received(:call).with("test", "テスト企業", user)
      end
    end
  end
end
