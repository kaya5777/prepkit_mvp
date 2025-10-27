require 'rails_helper'

RSpec.describe "Histories", type: :request do
  let(:history) do
    History.create!(
      content: '{"questions":["Q1"]}',
      asked_at: Time.current,
      memo: 'test'
    )
  end

  describe "GET /histories/:id" do
    it "returns http success" do
      get history_path(history)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /histories/new" do
    it "returns http success" do
      get new_history_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /histories/:id/edit" do
    it "returns http success" do
      get edit_history_path(history)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /histories" do
    it "creates a new history" do
      post histories_path, params: { history: { content: 'test', memo: 'memo' } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "PATCH /histories/:id" do
    it "updates the history" do
      patch history_path(history), params: { history: { memo: 'updated' } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /histories/:id" do
    it "deletes the history" do
      delete history_path(history)
      expect(response).to have_http_status(:redirect)
    end
  end
end
