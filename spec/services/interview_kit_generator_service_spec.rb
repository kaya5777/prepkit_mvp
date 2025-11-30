require 'rails_helper'

RSpec.describe InterviewKitGeneratorService do
  let(:job_description) { "Ruby on Rails エンジニア募集。経験3年以上。" }
  let(:company_name) { "テスト株式会社" }
  let(:user) { create(:user) }

  describe ".call" do
    context "when API key is missing" do
      before do
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("")
      end

      it "raises APIKeyMissingError" do
        expect {
          described_class.call(job_description)
        }.to raise_error(InterviewKitGeneratorService::APIKeyMissingError, /OpenAI の API キーが設定されていません/)
      end
    end

    context "when API key is present" do
      let(:valid_json_response) do
        <<~JSON
          ```json
          {
            "stage_1": {
              "questions": [
                {
                  "question": "Ruby on Railsでの開発経験について教えてください",
                  "intent": "実務経験の深さを確認したい",
                  "answer_points": ["具体的なプロジェクト", "担当した機能", "使用した技術"],
                  "level": "Mid-level Engineer"
                }
              ],
              "reverse_questions": "技術スタックや開発環境について質問しましょう",
              "tech_checklist": ["Rails のバージョン", "使用している gem"]
            },
            "stage_2": {
              "questions": [
                {
                  "question": "チーム開発での経験を教えてください",
                  "intent": "協調性を確認したい",
                  "answer_points": ["コミュニケーション", "チームワーク"],
                  "level": "Mid-level Engineer"
                }
              ],
              "reverse_questions": "チーム体制について質問しましょう",
              "tech_checklist": ["チーム規模"]
            },
            "stage_3": {
              "questions": [
                {
                  "question": "キャリアビジョンについて教えてください",
                  "intent": "長期的な視点を確認したい",
                  "answer_points": ["キャリアプラン"],
                  "level": "Mid-level Engineer"
                }
              ],
              "reverse_questions": "会社のビジョンについて質問しましょう",
              "tech_checklist": ["会社の方向性"]
            }
          }
          ```
        JSON
      end

      before do
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("test-api-key")
        allow(ENV).to receive(:[]).and_call_original

        fake_client = double("OpenAI::Client")
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)

        message = double("message", content: valid_json_response)
        choice = double("choice", message: message)
        chat_completion = double("chat_completion", choices: [choice])
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_return(chat_completion)
      end

      it "generates interview kit successfully" do
        result = described_class.call(job_description, company_name, user)

        expect(result).to have_key(:result)
        expect(result).to have_key(:history)
        expect(result[:result]).to have_key(:stage_1)
        expect(result[:result]).to have_key(:stage_2)
        expect(result[:result]).to have_key(:stage_3)
      end

      it "creates a history record" do
        expect {
          described_class.call(job_description, company_name, user)
        }.to change(History, :count).by(1)

        history = History.last
        expect(history.company_name).to eq(company_name)
        expect(history.user).to eq(user)
        expect(history.job_description).to eq(job_description)
      end

      it "normalizes questions correctly" do
        result = described_class.call(job_description, company_name, user)

        stage_1_questions = result[:result][:stage_1][:questions]
        expect(stage_1_questions).to be_an(Array)
        expect(stage_1_questions.first).to have_key(:question)
        expect(stage_1_questions.first).to have_key(:intent)
        expect(stage_1_questions.first).to have_key(:answer_points)
        expect(stage_1_questions.first).to have_key(:level)
      end
    end

    context "when OpenAI returns blank content" do
      before do
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("test-api-key")
        allow(ENV).to receive(:[]).and_call_original

        fake_client = double("OpenAI::Client")
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)

        message = double("message", content: "")
        choice = double("choice", message: message)
        chat_completion = double("chat_completion", choices: [choice])
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_return(chat_completion)
      end

      it "raises ContentBlankError" do
        expect {
          described_class.call(job_description)
        }.to raise_error(InterviewKitGeneratorService::ContentBlankError, /生成に失敗しました/)
      end
    end

    context "when OpenAI returns invalid JSON" do
      before do
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("test-api-key")
        allow(ENV).to receive(:[]).and_call_original

        fake_client = double("OpenAI::Client")
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)

        message = double("message", content: "invalid json {{{")
        choice = double("choice", message: message)
        chat_completion = double("chat_completion", choices: [choice])
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_return(chat_completion)
      end

      it "raises ParseError" do
        expect {
          described_class.call(job_description)
        }.to raise_error(InterviewKitGeneratorService::ParseError, /生成結果の形式が不正でした/)
      end
    end

    context "when OpenAI authentication fails" do
      before do
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("invalid-key")
        allow(ENV).to receive(:[]).and_call_original

        fake_client = double("OpenAI::Client")
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)

        auth_error = StandardError.new("status=>401")
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_raise(auth_error)
      end

      it "raises AuthenticationError" do
        expect {
          described_class.call(job_description)
        }.to raise_error(InterviewKitGeneratorService::AuthenticationError, /OpenAI への認証に失敗しました/)
      end
    end
  end

  describe "private methods" do
    let(:service) { described_class.new(job_description, company_name, user) }

    describe "#normalize_questions" do
      it "normalizes array of question hashes" do
        questions = [
          { question: "質問1", intent: "意図1", answer_points: ["ポイント1"], level: "Junior" }
        ]
        result = service.send(:normalize_questions, questions)

        expect(result.first[:question]).to eq("質問1")
        expect(result.first[:intent]).to eq("意図1")
        expect(result.first[:answer_points]).to eq(["ポイント1"])
        expect(result.first[:level]).to eq("Junior")
      end

      it "converts string questions to hash format" do
        questions = ["質問文字列"]
        result = service.send(:normalize_questions, questions)

        expect(result.first[:question]).to eq("質問文字列")
        expect(result.first[:intent]).to eq("")
        expect(result.first[:answer_points]).to eq([])
        expect(result.first[:level]).to eq("")
      end
    end

    describe "#normalize_reverse_questions" do
      it "returns string as is" do
        result = service.send(:normalize_reverse_questions, "逆質問のアドバイス")
        expect(result).to eq("逆質問のアドバイス")
      end

      it "joins array of strings" do
        result = service.send(:normalize_reverse_questions, ["質問1", "質問2"])
        expect(result).to eq("質問1\n質問2")
      end

      it "extracts question from array of hashes" do
        result = service.send(:normalize_reverse_questions, [{ question: "質問1" }, { question: "質問2" }])
        expect(result).to eq("質問1\n質問2")
      end

      it "returns empty string for nil" do
        result = service.send(:normalize_reverse_questions, nil)
        expect(result).to eq("")
      end
    end

    describe "#normalize_tech_checklist" do
      it "returns array as is when items are strings" do
        checklist = ["項目1", "項目2"]
        result = service.send(:normalize_tech_checklist, checklist)
        expect(result).to eq(["項目1", "項目2"])
      end

      it "extracts item from array of hashes" do
        checklist = [{ item: "項目1" }, { item: "項目2" }]
        result = service.send(:normalize_tech_checklist, checklist)
        expect(result).to eq(["項目1", "項目2"])
      end
    end

    describe "#safe_access" do
      it "returns nil for nil object" do
        result = service.send(:safe_access, nil, :choices)
        expect(result).to be_nil
      end

      it "accesses object attributes" do
        obj = double("object", choices: [1, 2, 3])
        result = service.send(:safe_access, obj, :choices)
        expect(result).to eq([1, 2, 3])
      end
    end

    describe "#parse_json_content" do
      it "parses JSON with backticks" do
        json_content = "```json\n{\"key\": \"value\"}\n```"
        result = service.send(:parse_json_content, json_content)
        expect(result[:key]).to eq("value")
      end

      it "parses plain JSON" do
        json_content = '{"key": "value"}'
        result = service.send(:parse_json_content, json_content)
        expect(result[:key]).to eq("value")
      end
    end
  end
end
