require 'rails_helper'

RSpec.describe "Simple interview kit generation", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
    sign_in user
  end

  # ユースケース1: トップページ（面接対策キット作成ページ）を表示する
  scenario "面接対策キット作成ページを表示できる" do
    visit root_path

    expect(page).to have_content("面接対策ノートを作成")
    expect(page).to have_field("job_description")
    expect(page).to have_button("想定質問を生成")
  end

  # ユースケース2: 面接対策キットを生成する（最小限）
  scenario "求人票を入力して面接対策キットを生成できる" do
    # サービスをモックして、historyを作成する
    allow(InterviewKitGeneratorService).to receive(:call) do |job_description, company_name, user|
      history = create(:history,
        user: user,
        company_name: company_name,
        content: '{"stage_1":{"questions":[{"question":"テスト質問"}]}}'
      )
      {
        result: JSON.parse(history.content, symbolize_names: true),
        history: history
      }
    end

    visit root_path
    fill_in "company_name", with: "テスト企業"
    fill_in "job_description", with: "Ruby on Railsエンジニア募集"
    click_button "想定質問を生成"

    # preparations/showテンプレートが表示される
    expect(current_path).to eq(preparations_path)
    expect(page).to have_content("テスト質問")
  end

  # ユースケース3: 自分の対策ノート一覧を表示する
  scenario "自分の対策ノート一覧を表示できる" do
    my_history = create(:history, user: user, company_name: "マイ企業")

    visit my_histories_histories_path

    expect(page).to have_content("自分の履歴")
    expect(page).to have_content("マイ企業")
  end

  # ユースケース4: 全体の対策ノート一覧を表示する
  scenario "全体の対策ノート一覧を表示できる" do
    my_history = create(:history, user: user, company_name: "マイ企業")
    other_history = create(:history, user: create(:user), company_name: "他ユーザー企業")

    visit all_histories_histories_path

    expect(page).to have_content("マイ企業")
    expect(page).to have_content("他ユーザー企業")
  end

  # ユースケース5: 対策ノートを編集する
  scenario "対策ノートの企業名を編集できる" do
    history = create(:history, user: user, company_name: "編集前")

    visit edit_history_path(history)
    fill_in "history[company_name]", with: "編集後"
    click_button "更新"

    expect(page).to have_content("編集後")
  end
end
