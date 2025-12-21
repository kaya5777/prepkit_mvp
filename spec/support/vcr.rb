require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false

  # OpenAI APIキーをフィルタリング（カセットに保存されないように）
  config.filter_sensitive_data("<OPENAI_API_KEY>") do |interaction|
    interaction.request.headers["Authorization"]&.first
  end

  # プロンプトテスト用のタグ設定
  # match_requests_on に :body を含めることで、プロンプト（リクエストボディ）が
  # 変わったら新しいAPIリクエストを送る（古いカセットを使わない）
  #
  # 重要: プロンプトを変更したら、必ずカセットを手動で削除してください！
  # 理由: VCRはリクエストボディ全体が一致しないと再記録しますが、
  #      プロンプトだけ変えた場合、一致判定が複雑になることがあります。
  #
  # 推奨ワークフロー:
  # 1. プロンプトを変更
  # 2. rm -rf spec/fixtures/vcr_cassettes/[対象のカセット]
  # 3. RUN_PROMPT_TESTS=true bundle exec rspec [対象のテスト]
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [ :method, :uri, :body ]  # bodyが変わったら再記録
  }
end
