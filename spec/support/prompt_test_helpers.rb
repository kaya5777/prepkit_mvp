module PromptTestHelpers
  # 職務経歴書とテキストコンテンツを作成
  def create_resume_with_content(text_content)
    user = create(:user)
    resume = create(:resume, :with_file, user: user)

    # raw_textを直接設定
    resume.update!(
      raw_text: text_content,
      status: "analyzed",
      analyzed_at: Time.current
    )

    resume
  end

  # 求人情報付きのHistoryを作成
  def create_history_with_job(company:, description:, user: nil)
    user ||= create(:user)
    create(:history,
      user: user,
      company_name: company,
      job_description: description
    )
  end

  # テストケースをスキップするかどうかを判定
  # 環境変数 RUN_PROMPT_TESTS=true がセットされている場合のみ実行
  def skip_unless_prompt_testing_enabled
    skip "Prompt testing disabled. Set RUN_PROMPT_TESTS=true to run." unless ENV["RUN_PROMPT_TESTS"] == "true"
  end
end

RSpec.configure do |config|
  config.include PromptTestHelpers, type: :service
end
