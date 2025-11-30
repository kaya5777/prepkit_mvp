require 'rails_helper'

RSpec.describe "Basic Navigation", type: :system do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  scenario "ユーザーが職務経歴書ページにアクセスできる" do
    visit resumes_path
    expect(page).to have_content("職務経歴書")
    expect(page).to have_http_status(:success)
  end

  scenario "ユーザーが自分の対策ノートページにアクセスできる" do
    visit my_histories_histories_path
    expect(page).to have_http_status(:success)
  end

  scenario "ユーザーが設定ページにアクセスできる" do
    visit settings_path
    expect(page).to have_content("設定")
    expect(page).to have_http_status(:success)
  end

  scenario "ログインしていないユーザーはログインページにリダイレクトされる" do
    sign_out user
    visit resumes_path
    expect(current_path).to eq(new_user_session_path)
  end
end
