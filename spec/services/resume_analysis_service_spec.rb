require "rails_helper"

RSpec.describe ResumeAnalysisService, type: :service do
  let(:user) { create(:user) }
  let(:resume) { create(:resume, :with_file, user: user) }
  let(:service) { described_class.new(resume) }

  before do
    # ResumeAnalysisService用のOpenAI APIスタブ
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
                content: mock_resume_analysis_response.to_json
              },
              finish_reason: "stop"
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # ResumeTextExtractorServiceのスタブ
    allow(ResumeTextExtractorService).to receive_message_chain(:new, :call).and_return(
      "職務経歴書\n氏名: 山田太郎\nWeb開発エンジニアとして5年の経験があります。"
    )
  end

  describe ".call" do
    it "calls instance method" do
      expect_any_instance_of(described_class).to receive(:call)
      described_class.call(resume)
    end
  end

  describe "#call" do
    context "when file is attached and analysis succeeds" do
      it "updates status to analyzing then analyzed" do
        expect {
          service.call
        }.to change { resume.reload.status }.from("draft").to("analyzed")
      end

      it "extracts and saves raw text" do
        service.call
        expect(resume.reload.raw_text).to be_present
      end

      it "creates resume analyses for all categories" do
        expect {
          service.call
        }.to change { resume.resume_analyses.count }.from(0).to(4)
      end

      it "saves summary" do
        service.call
        expect(resume.reload.summary).to be_present
      end

      it "sets analyzed_at timestamp" do
        service.call
        expect(resume.reload.analyzed_at).to be_present
      end

      it "saves feedback with good_points, issues, suggestions, and examples" do
        service.call
        analysis = resume.reload.resume_analyses.first
        
        expect(analysis.good_points).to be_an(Array)
        expect(analysis.issues).to be_an(Array)
        expect(analysis.suggestions).to be_an(Array)
        expect(analysis.examples).to be_an(Array)
        expect(analysis.examples.first).to have_key("before")
        expect(analysis.examples.first).to have_key("after")
      end

      it "saves scores for each category" do
        service.call
        resume.reload.resume_analyses.each do |analysis|
          expect(analysis.score).to be_between(0, 100)
        end
      end

      it "clamps scores to 0-100 range" do
        # OpenAI APIのモックレスポンスを変更して範囲外のスコアを返す
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [
                {
                  message: {
                    content: {
                      summary: "Test summary",
                      categories: {
                        structure: { score: 150, good_points: ["良い"], issues: [], suggestions: [], examples: [] },
                        content: { score: -10, good_points: ["良い"], issues: [], suggestions: [], examples: [] },
                        expression: { score: 75, good_points: ["良い"], issues: [], suggestions: [], examples: [] },
                        layout: { score: 75, good_points: ["良い"], issues: [], suggestions: [], examples: [] }
                      }
                    }.to_json
                  }
                }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        service.call
        scores = resume.reload.resume_analyses.pluck(:score)

        expect(scores).to all(be_between(0, 100))
        expect(scores).to include(100) # 150 clamped to 100
        expect(scores).to include(0)   # -10 clamped to 0
      end
    end

    context "when file is not attached" do
      let(:resume) { create(:resume, user: user) }

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(ResumeAnalysisService::AnalysisError, "ファイルがアップロードされていません")
      end

      it "does not change status" do
        expect {
          begin
            service.call
          rescue ResumeAnalysisService::AnalysisError
            # エラーを無視
          end
        }.not_to change { resume.reload.status }
      end
    end

    context "when text extraction fails" do
      before do
        allow(ResumeTextExtractorService).to receive_message_chain(:new, :call).and_raise(
          ResumeTextExtractorService::ExtractionError.new("抽出エラー")
        )
      end

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(ResumeAnalysisService::AnalysisError, "抽出エラー")
      end

      it "sets status to error" do
        begin
          service.call
        rescue ResumeAnalysisService::AnalysisError
          # エラーを無視
        end
        
        expect(resume.reload.status).to eq("error")
      end
    end

    context "when AI response is invalid JSON" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [{ message: { content: "Invalid JSON response" } }]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(ResumeAnalysisService::AnalysisError, "分析結果の解析に失敗しました")
      end

      it "sets status to error" do
        begin
          service.call
        rescue ResumeAnalysisService::AnalysisError
          # エラーを無視
        end
        
        expect(resume.reload.status).to eq("error")
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
                  content: { summary: "Test summary" }.to_json
                }
              }]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises AnalysisError" do
        expect {
          service.call
        }.to raise_error(ResumeAnalysisService::AnalysisError, "カテゴリ分析が含まれていません")
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
        }.to raise_error(ResumeAnalysisService::AnalysisError, "AIからの応答が空です")
      end
    end

    context "when resume already has analyses" do
      before do
        create_list(:resume_analysis, 4, resume: resume)
      end

      it "replaces old analyses with new ones" do
        old_ids = resume.resume_analyses.pluck(:id)
        
        service.call
        
        new_ids = resume.reload.resume_analyses.pluck(:id)
        expect(new_ids & old_ids).to be_empty # no overlap
        expect(new_ids.count).to eq(4)
      end
    end
  end

  describe "CATEGORIES" do
    it "has correct structure" do
      expect(ResumeAnalysisService::CATEGORIES).to be_a(Hash)
      expect(ResumeAnalysisService::CATEGORIES.keys).to contain_exactly(:structure, :content, :expression, :layout)
    end

    it "each category has name and description" do
      ResumeAnalysisService::CATEGORIES.each do |_key, value|
        expect(value).to have_key(:name)
        expect(value).to have_key(:description)
      end
    end
  end

  describe "prompt generation" do
    it "includes all categories in prompt" do
      prompt = service.send(:build_analysis_prompt, "test text")
      
      ResumeAnalysisService::CATEGORIES.each do |_key, value|
        expect(prompt).to include(value[:name])
        expect(prompt).to include(value[:description])
      end
    end

    it "truncates text to 8000 characters" do
      long_text = "a" * 10000
      prompt = service.send(:build_analysis_prompt, long_text)
      
      # プロンプト全体ではなく、埋め込まれたテキスト部分のみをチェック
      expect(prompt).to include("a" * 7997 + "...") # truncateは"..."を追加
    end

    it "includes examples in expected format" do
      prompt = service.send(:build_analysis_prompt, "test text")
      
      expect(prompt).to include('"examples"')
      expect(prompt).to include('"before"')
      expect(prompt).to include('"after"')
    end
  end

  describe "JSON parsing" do
    it "handles JSON wrapped in code blocks" do
      response = double(choices: [double(message: double(content: "```json\n{\"summary\":\"test\",\"categories\":{\"structure\":{},\"content\":{},\"expression\":{},\"layout\":{}}}\n```"))])
      
      result = service.send(:parse_analysis_response, response)
      
      expect(result).to be_a(Hash)
      expect(result[:summary]).to eq("test")
    end

    it "handles JSON without code blocks" do
      response = double(choices: [double(message: double(content: "{\"summary\":\"test\",\"categories\":{\"structure\":{},\"content\":{},\"expression\":{},\"layout\":{}}}"))])
      
      result = service.send(:parse_analysis_response, response)
      
      expect(result).to be_a(Hash)
      expect(result[:summary]).to eq("test")
    end
  end
end
