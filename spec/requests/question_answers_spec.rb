require 'rails_helper'

RSpec.describe "QuestionAnswers", type: :request do
  let(:user) { create(:user) }
  let(:history) { create(:history, user: user) }

  before do
    sign_in user
  end

  describe "GET /histories/:history_id/question_answers" do
    let!(:my_answer) { create(:question_answer, :scored, history: history, user: user) }

    it "returns http success" do
      get history_question_answers_path(history)
      expect(response).to have_http_status(:success)
    end

    it "displays the answer" do
      get history_question_answers_path(history)
      expect(response.body).to include(my_answer.user_answer)
    end
  end

  describe "GET /histories/:history_id/question_answers/new" do
    let(:history_with_questions) do
      create(:history,
        user: user,
        content: '```json
        {
          "questions": [
            {"question": "質問1", "intent": "意図1", "answer_points": ["ポイント1"], "level": "Junior"}
          ]
        }
        ```'
      )
    end

    it "returns http success" do
      get new_history_question_answer_path(history_with_questions, question_index: 0)
      expect(response).to have_http_status(:success)
    end

    it "redirects when question not found" do
      get new_history_question_answer_path(history_with_questions, question_index: 999)
      expect(response).to redirect_to(history_path(history_with_questions))
      follow_redirect!
      expect(response.body).to include("質問が見つかりません")
    end
  end

  describe "POST /histories/:history_id/question_answers" do
    let(:history_with_questions) do
      create(:history,
        user: user,
        content: '```json
        {
          "questions": [
            {"question": "質問1", "intent": "意図1", "answer_points": ["ポイント1"], "level": "Junior"}
          ]
        }
        ```'
      )
    end

    let(:valid_params) do
      {
        question_answer: {
          question_index: 0,
          question_text: "質問1",
          user_answer: "私の回答です"
        }
      }
    end

    before do
      allow(QuestionAnswerScoringService).to receive(:call).and_return({
        score: 75,
        good_points: ["良い点"],
        improvements: ["改善点"],
        improvement_example: "改善例"
      })
    end

    context "with valid parameters for scoring" do
      it "creates a question answer" do
        expect {
          post history_question_answers_path(history_with_questions), params: valid_params
        }.to change(QuestionAnswer, :count).by(1)
      end

      it "sets status to scored" do
        post history_question_answers_path(history_with_questions), params: valid_params
        expect(QuestionAnswer.last.status).to eq("scored")
      end

      it "redirects to show page" do
        post history_question_answers_path(history_with_questions), params: valid_params
        expect(response).to redirect_to(history_question_answer_path(history_with_questions, QuestionAnswer.last))
      end
    end

    context "with save_only parameter" do
      it "saves as draft" do
        post history_question_answers_path(history_with_questions), params: valid_params.merge(save_only: true)
        expect(QuestionAnswer.last.status).to eq("draft")
      end

      it "redirects to history page" do
        post history_question_answers_path(history_with_questions), params: valid_params.merge(save_only: true)
        expect(response).to redirect_to(history_path(history_with_questions))
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          question_answer: {
            question_index: 0,
            question_text: "",
            user_answer: ""
          }
        }
      end

      it "does not create a question answer" do
        expect {
          post history_question_answers_path(history_with_questions), params: invalid_params
        }.not_to change(QuestionAnswer, :count)
      end

      it "renders new template with unprocessable_entity" do
        post history_question_answers_path(history_with_questions), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when scoring service fails" do
      before do
        allow(QuestionAnswerScoringService).to receive(:call).and_raise(
          QuestionAnswerScoringService::ScoringError.new("採点に失敗しました")
        )
      end

      it "does not create a question answer" do
        expect {
          post history_question_answers_path(history_with_questions), params: valid_params
        }.not_to change(QuestionAnswer, :count)
      end

      it "renders new template with error" do
        post history_question_answers_path(history_with_questions), params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("採点に失敗しました")
      end
    end
  end

  describe "GET /histories/:history_id/question_answers/:id" do
    let(:question_answer) { create(:question_answer, :scored, history: history, user: user) }

    it "returns http success" do
      get history_question_answer_path(history, question_answer)
      expect(response).to have_http_status(:success)
    end

    it "displays the scored answer" do
      get history_question_answer_path(history, question_answer)
      expect(response.body).to include(question_answer.user_answer)
    end
  end

  describe "DELETE /histories/:history_id/question_answers/:id" do
    let!(:question_answer) { create(:question_answer, history: history, user: user) }

    it "destroys the answer" do
      expect {
        delete history_question_answer_path(history, question_answer)
      }.to change(QuestionAnswer, :count).by(-1)
    end

    it "redirects to history with notice" do
      delete history_question_answer_path(history, question_answer)
      expect(response).to redirect_to(history_path(history))
      follow_redirect!
      expect(response.body).to include("回答を削除しました")
    end
  end

  context "when not signed in" do
    before { sign_out user }

    it "redirects to sign in" do
      get history_question_answers_path(history)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
