require 'rails_helper'

RSpec.describe QuestionAnswerScoringService do
  let(:question_data) do
    {
      question: "Ruby on Railsでの開発経験を教えてください",
      intent: "実務経験の深さを確認したい",
      answer_points: [ "具体的なプロジェクト", "使用した技術", "チーム規模" ],
      level: "Mid-level Engineer"
    }
  end
  let(:user_answer) { "3年間のRails開発経験があり、ECサイトの構築を担当しました。" }

  describe ".call" do
    context "when inputs are valid" do
      let(:mock_response_content) do
        {
          "score" => 85,
          "good_points" => [ "具体的な経験年数を記載", "プロジェクト内容に言及" ],
          "improvements" => [ "技術スタックの詳細が不足" ],
          "improvement_example" => "Ruby 3.0、Rails 7.0を使用し、決済機能を実装しました。"
        }.to_json
      end

      before do
        fake_client = double("OpenAI::Client")
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)

        message = double("message", content: mock_response_content)
        choice = double("choice", message: message)
        response = double("response", choices: [ choice ])
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_return(response)
      end

      it "returns scoring result" do
        result = described_class.call(question_data, user_answer)

        expect(result[:score]).to eq(85)
        expect(result[:good_points]).to be_an(Array)
        expect(result[:improvements]).to be_an(Array)
        expect(result[:improvement_example]).to be_a(String)
      end

      it "clamps score to 0-100 range" do
        result = described_class.call(question_data, user_answer)
        expect(result[:score]).to be_between(0, 100)
      end
    end

    context "when OpenAI returns invalid response" do
      before do
        fake_client = double("OpenAI::Client")
        allow(OpenAI::Client).to receive(:new).and_return(fake_client)
        allow(fake_client).to receive_message_chain(:chat, :completions, :create).and_raise(StandardError.new("API Error"))
      end

      it "raises ScoringError" do
        expect {
          described_class.call(question_data, user_answer)
        }.to raise_error(QuestionAnswerScoringService::ScoringError, /採点に失敗しました/)
      end
    end
  end

  describe "private methods" do
    let(:service) { described_class.new(question_data, user_answer) }

    describe "#validate_inputs!" do
      it "raises error when question is blank" do
        service_with_blank_question = described_class.new({ question: "" }, user_answer)
        expect {
          service_with_blank_question.send(:validate_inputs!)
        }.to raise_error(QuestionAnswerScoringService::ScoringError, /質問文が指定されていません/)
      end

      it "raises error when answer is blank" do
        service_with_blank_answer = described_class.new(question_data, "")
        expect {
          service_with_blank_answer.send(:validate_inputs!)
        }.to raise_error(QuestionAnswerScoringService::ScoringError, /回答が入力されていません/)
      end
    end

    describe "#normalize_result" do
      it "normalizes result with all fields" do
        parsed = {
          score: 75,
          good_points: [ "良い点1" ],
          improvements: [ "改善点1" ],
          improvement_example: "改善例"
        }
        result = service.send(:normalize_result, parsed)

        expect(result[:score]).to eq(75)
        expect(result[:good_points]).to eq([ "良い点1" ])
        expect(result[:improvements]).to eq([ "改善点1" ])
        expect(result[:improvement_example]).to eq("改善例")
      end

      it "clamps score over 100" do
        parsed = { score: 150, good_points: [], improvements: [] }
        result = service.send(:normalize_result, parsed)
        expect(result[:score]).to eq(100)
      end

      it "clamps score under 0" do
        parsed = { score: -10, good_points: [], improvements: [] }
        result = service.send(:normalize_result, parsed)
        expect(result[:score]).to eq(0)
      end
    end

    describe "#scoring_criteria_text" do
      it "generates criteria text" do
        text = service.send(:scoring_criteria_text)
        expect(text).to include("内容の正確性")
        expect(text).to include("30点")
      end
    end
  end
end
