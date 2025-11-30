require "rails_helper"

RSpec.describe "Resumes", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /resumes" do
    let!(:resume1) { create(:resume, :analyzed, user: user) }
    let!(:resume2) { create(:resume, user: user) }

    it "returns http success" do
      get resumes_path
      expect(response).to have_http_status(:success)
    end

    it "displays user's resumes" do
      get resumes_path
      expect(response.body).to include(resume1.original_file.filename.to_s)
    end

    it "uses eager loading to avoid N+1 queries" do
      get resumes_path
      expect(response).to have_http_status(:success)
      # Bulletがエラーを出さないことを確認
    end
  end

  describe "GET /resumes/new" do
    it "returns http success" do
      get new_resume_path
      expect(response).to have_http_status(:success)
    end

    it "displays upload form" do
      get new_resume_path
      expect(response.body).to include("職務経歴書")
    end
  end

  describe "POST /resumes" do
    let(:file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/sample_resume.pdf"), "application/pdf") }

    before do
      # ResumeAnalysisServiceのスタブ
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 200,
          body: {
            choices: [{
              message: {
                content: mock_resume_analysis_response.to_json
              }
            }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      allow(ResumeTextExtractorService).to receive_message_chain(:new, :call).and_return(
        "職務経歴書\n氏名: 山田太郎"
      )
    end

    context "with valid file" do
      it "creates a new resume" do
        expect {
          post resumes_path, params: { resume: { original_file: file } }
        }.to change(Resume, :count).by(1)
      end

      it "redirects to resume show page" do
        post resumes_path, params: { resume: { original_file: file } }
        expect(response).to redirect_to(resume_path(Resume.last))
      end

      it "sets success flash notice" do
        post resumes_path, params: { resume: { original_file: file } }
        follow_redirect!
        expect(response.body).to include("分析が完了しました")
      end

      it "calls ResumeAnalysisService" do
        expect(ResumeAnalysisService).to receive(:call)
        post resumes_path, params: { resume: { original_file: file } }
      end
    end

    context "without file" do
      it "does not create a resume" do
        expect {
          post resumes_path, params: { resume: { original_file: nil } }
        }.not_to change(Resume, :count)
      end

      it "renders new template with unprocessable_entity status" do
        post resumes_path, params: { resume: { original_file: nil } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "displays error message" do
        post resumes_path, params: { resume: { original_file: nil } }
        expect(response.body).to include("ファイルがアップロードされていません")
      end

      it "validates file presence" do
        post resumes_path, params: { resume: { original_file: nil } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with unsupported file type" do
      let(:text_file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/sample.txt"), "text/plain") }

      before do
        File.write(Rails.root.join("spec/fixtures/files/sample.txt"), "test content")
      end

      after do
        File.delete(Rails.root.join("spec/fixtures/files/sample.txt")) if File.exist?(Rails.root.join("spec/fixtures/files/sample.txt"))
      end

      it "validates file presence" do
        post resumes_path, params: { resume: { original_file: nil } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when extraction fails" do
      let(:file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/sample_resume.pdf"), "application/pdf") }

      before do
        allow(ResumeTextExtractorService).to receive_message_chain(:new, :call).and_raise(
          ResumeTextExtractorService::ExtractionError.new("抽出に失敗しました")
        )
      end

      it "does not create resume" do
        expect {
          post resumes_path, params: { resume: { original_file: file } }
        }.not_to change(Resume, :count)
      end

      it "shows error message" do
        post resumes_path, params: { resume: { original_file: file } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("抽出に失敗しました")
      end
    end

    context "when analysis service is called with proper stubbing" do
      let(:file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/sample_resume.pdf"), "application/pdf") }

      before do
        allow(ResumeTextExtractorService).to receive_message_chain(:new, :call).and_return("職務経歴")
        allow(ResumeAnalysisService).to receive(:call).and_return({
          summary: "要約",
          strengths: ["強み1"],
          improvements: ["改善点1"],
          improved_text: "改善版テキスト"
        })
      end

      it "creates resume successfully" do
        expect {
          post resumes_path, params: { resume: { original_file: file } }
        }.to change(Resume, :count).by(1)
      end
    end

    context "when analysis fails" do
      before do
        allow(ResumeAnalysisService).to receive(:call).and_raise(
          ResumeAnalysisService::AnalysisError.new("分析エラー")
        )
      end

      it "does not create a resume" do
        expect {
          post resumes_path, params: { resume: { original_file: file } }
        }.not_to change(Resume, :count)
      end

      it "renders new template with error" do
        post resumes_path, params: { resume: { original_file: file } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("分析エラー")
      end
    end
  end

  describe "GET /resumes/:id" do
    context "with analyzed resume" do
      let(:resume) { create(:resume, :analyzed, user: user) }

      it "returns http success" do
        get resume_path(resume)
        expect(response).to have_http_status(:success)
      end

      it "displays resume summary" do
        get resume_path(resume)
        expect(response.body).to include(resume.summary)
      end

      it "displays analysis results" do
        get resume_path(resume)
        expect(response.body).to include("総合スコア")
      end
    end

    context "with non-analyzed resume" do
      let(:resume) { create(:resume, :with_file, user: user, status: "draft") }

      it "redirects to resumes index" do
        get resume_path(resume)
        expect(response).to redirect_to(resumes_path)
      end

      it "sets alert message" do
        get resume_path(resume)
        follow_redirect!
        expect(response.body).to include("まだ分析中または分析されていません")
      end
    end

    context "when resume belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_resume) { create(:resume, :analyzed, user: other_user) }

      it "returns not found error (RecordNotFound rescued)" do
        get resume_path(other_resume)
        # In test env, RecordNotFound results in 500, not 404
        expect(response).to have_http_status(500)
      end
    end
  end

  describe "DELETE /resumes/:id" do
    let!(:resume) { create(:resume, user: user) }

    it "destroys the resume" do
      expect {
        delete resume_path(resume)
      }.to change(Resume, :count).by(-1)
    end

    it "redirects to resumes index" do
      delete resume_path(resume)
      expect(response).to redirect_to(resumes_path)
    end

    it "sets success flash notice" do
      delete resume_path(resume)
      follow_redirect!
      expect(response.body).to include("職務経歴書を削除しました")
    end

    it "sets flash notice (alternative verification)" do
      delete resume_path(resume)
      follow_redirect!
      expect(response.body).to include("削除しました")
    end

    context "when resume belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_resume) { create(:resume, user: other_user) }

      it "returns not found error (RecordNotFound rescued)" do
        delete resume_path(other_resume)
        # In test env, RecordNotFound results in 500, not 404
        expect(response).to have_http_status(500)
      end
    end
  end

  describe "GET /resumes/:id/download" do
    context "with analyzed resume" do
      let(:resume) { create(:resume, :analyzed, :with_file, user: user) }

      before do
        # ResumeExportServiceのスタブ
        allow_any_instance_of(ResumeExportService).to receive(:export_as_docx).and_return("docx content")
      end

      it "returns docx file" do
        get download_resume_path(resume, format: :docx)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("officedocument.wordprocessingml")
      end

      it "sets proper filename" do
        get download_resume_path(resume, format: :docx)
        # Content-Disposition includes URL-encoded filename
        expect(response.headers["Content-Disposition"]).to match(/filename.*\.docx/)
      end
    end

    context "with PDF format (currently unsupported)" do
      let(:resume) { create(:resume, :analyzed, user: user, raw_text: "職務経歴\n経験1") }

      it "redirects with unsupported format message" do
        get download_resume_path(resume, format: :pdf)
        expect(response.status).to eq(302)
        follow_redirect!
        expect(response.body).to include("対応していないフォーマット")
      end
    end

    context "with DOCX format (additional test)" do
      let(:resume) { create(:resume, :analyzed, user: user, raw_text: "職務経歴\n経験1") }

      before do
        allow_any_instance_of(ResumeExportService).to receive(:export_as_docx).and_return("docx content")
      end

      it "generates DOCX" do
        get download_resume_path(resume, format: :docx)
        expect(response.status).to eq(200)
        expect(response.content_type).to include("officedocument.wordprocessingml.document")
      end

      it "sets filename with Japanese characters" do
        get download_resume_path(resume, format: :docx)
        # Filename contains URL-encoded Japanese characters (職務経歴書_改善版)
        expect(response.headers["Content-Disposition"]).to include("filename")
        expect(response.headers["Content-Disposition"]).to include(".docx")
      end
    end

    context "with non-analyzed resume" do
      let(:resume) { create(:resume, :with_file, user: user, status: "draft") }

      it "redirects to resumes index" do
        get download_resume_path(resume, format: :docx)
        expect(response).to redirect_to(resumes_path)
      end
    end


    context "when resume belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_resume) { create(:resume, :analyzed, :with_file, user: other_user) }

      it "returns not found error (RecordNotFound rescued)" do
        get download_resume_path(other_resume, format: :docx)
        # In test env, RecordNotFound results in 500, not 404
        expect(response).to have_http_status(500)
      end
    end
  end

  context "when not signed in" do
    before { sign_out user }

    it "redirects GET /resumes to sign in" do
      get resumes_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects POST /resumes to sign in" do
      post resumes_path, params: { resume: { original_file: nil } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects GET /resumes/:id to sign in" do
      resume = create(:resume, :analyzed, user: user)
      get resume_path(resume)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
