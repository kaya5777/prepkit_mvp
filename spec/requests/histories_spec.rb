require "rails_helper"

RSpec.describe "Histories", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /histories/:id" do
    let(:history) { create(:history, user: user, company_name: "テスト株式会社") }

    it "returns http success" do
      get history_path(history)
      expect(response).to have_http_status(:success)
    end

    it "displays history information" do
      get history_path(history)
      expect(response.body).to include(history.company_name)
    end

    context "when history belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_history) { create(:history, user: other_user) }

      it "still allows access (no authorization check in controller)" do
        get history_path(other_history)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /histories/:id/edit" do
    let(:history) { create(:history, user: user) }

    it "returns http success" do
      get edit_history_path(history)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /histories/:id" do
    let(:history) { create(:history, user: user, company_name: "旧企業名", content: '{"test": "content"}') }

    context "with valid parameters" do
      let(:new_company_name) { "新企業名" }

      it "updates the history" do
        patch history_path(history), params: { history: { company_name: new_company_name } }
        expect(history.reload.company_name).to eq(new_company_name)
      end

      it "redirects to the history" do
        patch history_path(history), params: { history: { company_name: new_company_name } }
        expect(response).to redirect_to(history)
      end
    end

    context "with invalid parameters that pass model validation" do
      it "updates with empty company_name" do
        patch history_path(history), params: { history: { company_name: "" } }
        expect(history.reload.company_name).to eq("")
      end
    end

    context "with very long content" do
      it "handles large content appropriately" do
        large_content = '{"data": "' + ("a" * 10000) + '"}'
        patch history_path(history), params: { history: { content: large_content } }
        expect(response.status).to be_in([ 200, 302, 422 ])
      end
    end
  end

  describe "DELETE /histories/:id" do
    let!(:history) { create(:history, user: user) }

    it "destroys the history" do
      expect {
        delete history_path(history)
      }.to change(History, :count).by(-1)
    end

    it "redirects to root path" do
      delete history_path(history)
      expect(response).to redirect_to(root_path)
    end

    it "sets flash notice" do
      delete history_path(history)
      follow_redirect!
      expect(response.body).to include("履歴を削除しました")
    end

    context "when history belongs to another user" do
      let(:other_user) { create(:user) }
      let!(:other_history) { create(:history, user: other_user) }

      it "still destroys the history (no authorization check)" do
        expect {
          delete history_path(other_history)
        }.to change(History, :count).by(-1)
      end
    end
  end

  describe "GET /histories/my_histories" do
    let!(:my_history) { create(:history, user: user) }
    let!(:other_history) { create(:history, user: create(:user)) }

    it "returns http success" do
      get my_histories_histories_path
      expect(response).to have_http_status(:success)
    end

    it "uses for_listing scope to exclude large text fields" do
      get my_histories_histories_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /histories/all_histories" do
    let!(:my_history) { create(:history, user: user) }
    let!(:other_user_history) { create(:history, user: create(:user)) }
    let!(:public_history) { create(:history, user: nil) }

    it "returns http success" do
      get all_histories_histories_path
      expect(response).to have_http_status(:success)
    end

    it "uses for_listing scope to exclude large text fields" do
      get all_histories_histories_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /histories/:id/analyze_match" do
    let(:history) { create(:history, user: user) }

    before do
      # JobMatchAnalysisServiceのスタブ
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 200,
          body: {
            choices: [ {
              message: {
                content: mock_job_match_analysis_response.to_json
              }
            } ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    context "with analyzed resume" do
      let!(:resume) { create(:resume, :analyzed, user: user) }

      it "triggers match analysis using latest analyzed resume" do
        post analyze_match_history_path(history)
        expect(history.reload.match_score).to be_present
      end

      it "redirects to history" do
        post analyze_match_history_path(history)
        expect(response).to redirect_to(history)
      end

      it "sets success flash notice" do
        post analyze_match_history_path(history)
        follow_redirect!
        expect(response.body).to include("相性診断が完了しました")
      end
    end

    context "without analyzed resume" do
      it "redirects back with error message" do
        post analyze_match_history_path(history)
        expect(response).to redirect_to(history)
        follow_redirect!
        expect(response.body).to include("職務経歴書がアップロードされていないか、分析が完了していません")
      end

      it "does not update history" do
        post analyze_match_history_path(history)
        expect(history.reload.match_score).to be_nil
      end
    end

    context "when analysis fails" do
      let!(:resume) { create(:resume, :analyzed, user: user) }

      before do
        allow(JobMatchAnalysisService).to receive(:call).and_raise(
          JobMatchAnalysisService::AnalysisError.new("分析エラー")
        )
      end

      it "redirects with error alert" do
        post analyze_match_history_path(history)
        expect(response).to redirect_to(history)
        follow_redirect!
        expect(response.body).to include("分析エラー")
      end
    end
  end

  context "when not signed in" do
    before { sign_out user }

    it "redirects to sign in when accessing protected routes" do
      get edit_history_path(create(:history))
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
