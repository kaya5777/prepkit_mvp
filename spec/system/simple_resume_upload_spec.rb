require 'rails_helper'

RSpec.describe "Simple resume upload", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
    sign_in user
  end

  # ユースケース1: 職務経歴書一覧ページを表示する
  scenario "職務経歴書一覧ページを表示できる" do
    visit resumes_path

    expect(page).to have_content("職務経歴書の添削")
    expect(page).to have_link("新規アップロード")
  end

  # ユースケース2: 新規アップロードページを表示する
  scenario "新規アップロードページを表示できる" do
    visit new_resume_path

    expect(page).to have_content("職務経歴書をアップロード")
    expect(page).to have_button("分析を開始")
  end

  # ユースケース3: ファイルなしで送信した場合のバリデーション
  # (rack_testでは例外が発生してエラーページになるため、Request Specでテスト済み)
  # scenario "ファイルを選択せずに送信するとエラーが表示される"

  # ユースケース4: 既存の職務経歴書を一覧に表示する
  scenario "既存の職務経歴書が一覧に表示される" do
    resume = create(:resume, :analyzed, user: user)

    visit resumes_path

    expect(page).to have_content(resume.original_file.filename.to_s)
    expect(page).to have_content("分析完了")
  end

  # ユースケース5: 職務経歴書をアップロードする（最小限）
  scenario "職務経歴書をアップロードできる" do
    # 分析サービスをモックして、statusだけ更新する
    allow(ResumeAnalysisService).to receive(:call) do |resume|
      resume.update!(
        status: "analyzed",
        summary: "テストサマリー",
        raw_text: "テストテキスト"
      )
    end

    visit new_resume_path
    attach_file "resume[original_file]", Rails.root.join("spec/fixtures/files/sample_resume.pdf")
    click_button "分析を開始"

    # 分析完了後、詳細ページにリダイレクトされる
    expect(page).to have_content("分析が完了しました")
  end
end
