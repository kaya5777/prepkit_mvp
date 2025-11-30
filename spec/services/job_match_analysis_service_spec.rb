require "rails_helper"

RSpec.describe JobMatchAnalysisService, type: :service do
  let(:user) { create(:user) }
  let(:resume) { create(:resume, :analyzed, user: user) }
  let(:history) { create(:history, user: user, company_name: "テスト株式会社", job_description: "Railsエンジニア募集") }
  let(:service) { described_class.new(history, resume) }

  before do
    # JobMatchAnalysisService用のOpenAI APIスタブ
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          id: "chatcmpl-test",
          object: "chat.completion",
          created: Time.current.to_i,
          model: "gpt-4o-mini",
          choices: [
            {
              index: 0,
              message: {
                role: "assistant",
                content: mock_job_match_analysis_response.to_json
              },
              finish_reason: "stop"
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe ".call" do
    it "calls instance method" do
      expect_any_instance_of(described_class).to receive(:call)
      described_class.call(history, resume)
    end
  end

  describe "#call" do
    context "when inputs are valid" do
      it "updates history with match analysis" do
        expect {
          service.call
        }.to change { history.reload.match_score }.from(nil)
      end

      it "saves match_score" do
        service.call
        expect(history.reload.match_score).to be_between(0, 100)
      end

      it "saves match_rank" do
        service.call
        expect(history.reload.match_rank).to be_in(%w[S A B C D])
      end

      it "saves match_analysis with all required fields" do
        service.call
        analysis = history.reload.match_analysis
        
        expect(analysis).to be_a(Hash)
        expect(analysis).to have_key("matching_points")
        expect(analysis).to have_key("gap_points")
        expect(analysis).to have_key("appeal_suggestions")
        expect(analysis).to have_key("interview_tips")
        expect(analysis).to have_key("summary")
        expect(analysis).to have_key("analyzed_at")
        expect(analysis).to have_key("resume_id")
      end

      it "saves matching_points as array" do
        service.call
        matching_points = history.reload.match_analysis["matching_points"]
        
        expect(matching_points).to be_an(Array)
        expect(matching_points).not_to be_empty
        expect(matching_points.first).to have_key("requirement")
        expect(matching_points.first).to have_key("experience")
        expect(matching_points.first).to have_key("strength")
      end

      it "saves gap_points as array" do
        service.call
        gap_points = history.reload.match_analysis["gap_points"]
        
        expect(gap_points).to be_an(Array)
      end

      it "saves appeal_suggestions as array" do
        service.call
        suggestions = history.reload.match_analysis["appeal_suggestions"]
        
        expect(suggestions).to be_an(Array)
        expect(suggestions).not_to be_empty
      end

      it "saves interview_tips as array" do
        service.call
        tips = history.reload.match_analysis["interview_tips"]
        
        expect(tips).to be_an(Array)
        expect(tips).not_to be_empty
      end

      it "saves resume_id in match_analysis" do
        service.call
        expect(history.reload.match_analysis["resume_id"]).to eq(resume.id)
      end

      it "saves analyzed_at timestamp" do
        service.call
        expect(history.reload.match_analysis["analyzed_at"]).to be_present
      end

      it "clamps score to 0-100 range" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [{
                message: {
                  content: {
                    match_score: 150,
                    match_rank: "S",
                    matching_points: [],
                    gap_points: [],
                    appeal_suggestions: [],
                    interview_tips: [],
                    summary: "Test"
                  }.to_json
                }
              }]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        service.call
        expect(history.reload.match_score).to eq(100)
      end
    end

    context "when history is nil" do
      let(:service) { described_class.new(nil, resume) }

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(JobMatchAnalysisService::AnalysisError, "対策ノートが指定されていません")
      end
    end

    context "when resume is nil" do
      let(:service) { described_class.new(history, nil) }

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(JobMatchAnalysisService::AnalysisError, "職務経歴書が指定されていません")
      end
    end

    context "when resume is not analyzed" do
      let(:resume) { create(:resume, :with_file, user: user, status: "draft") }

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(JobMatchAnalysisService::AnalysisError, "職務経歴書が分析されていません")
      end
    end

    context "when AI response is invalid JSON" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [{ message: { content: "Invalid JSON" } }]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(JobMatchAnalysisService::AnalysisError, "分析結果の解析に失敗しました")
      end
    end

    context "when AI response is missing required fields" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [{
                message: {
                  content: { match_score: 75 }.to_json
                }
              }]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(JobMatchAnalysisService::AnalysisError, "ランクが含まれていません")
      end
    end

    context "when AI response is empty" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [{ message: { content: nil } }]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(JobMatchAnalysisService::AnalysisError, "AIからの応答が空です")
      end
    end

    context "when history has content with questions" do
      let(:history) do
        create(:history, user: user, company_name: "テスト株式会社", content: {
          questions: [
            { question: "自己PRをお願いします", category: "general" },
            { question: "志望動機を教えてください", category: "motivation" }
          ]
        }.to_json)
      end

      it "includes questions in job info" do
        job_info = service.send(:build_job_info)
        expect(job_info).to include("自己PRをお願いします")
        expect(job_info).to include("志望動機を教えてください")
      end

      it "truncates job info to 3000 characters" do
        long_description = "a" * 4000
        history.update!(job_description: long_description)
        
        job_info = service.send(:build_job_info)
        expect(job_info.length).to be <= 3000
      end
    end
  end

  describe "RANK_DEFINITIONS" do
    it "has correct structure" do
      expect(JobMatchAnalysisService::RANK_DEFINITIONS).to be_a(Hash)
      expect(JobMatchAnalysisService::RANK_DEFINITIONS.keys).to contain_exactly("S", "A", "B", "C", "D")
    end

    it "each rank has range, label, and description" do
      JobMatchAnalysisService::RANK_DEFINITIONS.each do |_key, value|
        expect(value).to have_key(:range)
        expect(value).to have_key(:label)
        expect(value).to have_key(:description)
      end
    end

    it "ranges cover 0-100" do
      all_scores = (0..100).to_a
      covered_scores = []
      
      JobMatchAnalysisService::RANK_DEFINITIONS.each do |_key, value|
        covered_scores += value[:range].to_a
      end
      
      expect(covered_scores.uniq.sort).to eq(all_scores)
    end
  end

  describe ".rank_info" do
    it "returns correct info for S rank" do
      info = described_class.rank_info("S")
      expect(info[:label]).to eq("非常に高い")
      expect(info[:range]).to eq(90..100)
    end

    it "returns correct info for A rank" do
      info = described_class.rank_info("A")
      expect(info[:label]).to eq("高い")
      expect(info[:range]).to eq(80..89)
    end

    it "returns correct info for B rank" do
      info = described_class.rank_info("B")
      expect(info[:label]).to eq("やや高い")
      expect(info[:range]).to eq(70..79)
    end

    it "returns correct info for C rank" do
      info = described_class.rank_info("C")
      expect(info[:label]).to eq("普通")
      expect(info[:range]).to eq(60..69)
    end

    it "returns correct info for D rank" do
      info = described_class.rank_info("D")
      expect(info[:label]).to eq("要改善")
      expect(info[:range]).to eq(0..59)
    end

    it "returns D rank info for invalid rank" do
      info = described_class.rank_info("X")
      expect(info).to eq(JobMatchAnalysisService::RANK_DEFINITIONS["D"])
    end
  end

  describe "prompt generation" do
    it "includes company name" do
      prompt = service.send(:build_analysis_prompt)
      expect(prompt).to include(history.company_name)
    end

    it "includes job description" do
      prompt = service.send(:build_analysis_prompt)
      expect(prompt).to include(history.job_description)
    end

    it "includes resume text" do
      prompt = service.send(:build_analysis_prompt)
      expect(prompt).to include(resume.raw_text.truncate(4000))
    end

    it "includes rank definitions in output format" do
      prompt = service.send(:build_analysis_prompt)
      expect(prompt).to include("90以上:S")
      expect(prompt).to include("80-89:A")
      expect(prompt).to include("70-79:B")
      expect(prompt).to include("60-69:C")
      expect(prompt).to include("59以下:D")
    end
  end

  describe "JSON parsing" do
    it "handles JSON wrapped in code blocks" do
      response = double(choices: [double(message: double(content: "```json\n{\"match_score\":75,\"match_rank\":\"B\"}\n```"))])
      
      result = service.send(:parse_analysis_response, response)
      
      expect(result).to be_a(Hash)
      expect(result[:match_score]).to eq(75)
      expect(result[:match_rank]).to eq("B")
    end

    it "handles JSON without code blocks" do
      response = double(choices: [double(message: double(content: "{\"match_score\":85,\"match_rank\":\"A\"}"))])
      
      result = service.send(:parse_analysis_response, response)
      
      expect(result).to be_a(Hash)
      expect(result[:match_score]).to eq(85)
    end
  end
end
