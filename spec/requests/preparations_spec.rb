require 'rails_helper'

RSpec.describe "Preparations", type: :request do
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
        # InterviewKitGeneratorService raises an error which becomes 500
        expect(response.status).to be >= 400
        expect(response.body).to include('エラーが発生しました')
      end
    end

    context "when OpenAI returns valid JSON" do
      it "renders show successfully" do
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("test")
        allow(ENV).to receive(:[]).and_call_original
        fake_client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)
        message = double('message', content: {
          questions: [ "Q1" ],
          star_answers: [
            { question: "Q1", situation: "S", task: "T", action: "A", result: "R" }
          ],
          reverse_questions: [ "RQ1" ],
          tech_checklist: [ "C1" ]
        }.to_json)
        choice = double('choice', message: message)
        chat_completion = double('chat_completion', choices: [ choice ])
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_return(chat_completion)

        post preparations_path, params: { job_description: "foo" }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
