# LLMプロバイダー移行ガイド

このドキュメントでは、OpenAI APIからGoogle Gemini APIへの移行、または両方を併用する方法について説明します。

## 概要

このアプリケーションは、OpenAIとGoogle Geminiの両方のLLMプロバイダーをサポートしています。
`LlmClient`という抽象化レイヤーを通じて、プロバイダーを簡単に切り替えることができます。

## アーキテクチャ

### LlmClient（抽象化レイヤー）

[app/services/llm_client.rb](../app/services/llm_client.rb)

すべてのサービスは`LlmClient`を通じてLLM APIを呼び出します：

```ruby
client = LlmClient.new
response = client.chat(
  system: "あなたはアシスタントです",
  user: "こんにちは",
  temperature: 0.5
)
content = response.content
```

### 対応サービス

以下のサービスがLlmClientを使用しています：

- [app/services/job_match_analysis_service.rb](../app/services/job_match_analysis_service.rb) - 職務経歴書マッチング分析
- [app/services/resume_analysis_service.rb](../app/services/resume_analysis_service.rb) - 職務経歴書品質評価
- [app/services/interview_kit_generator_service.rb](../app/services/interview_kit_generator_service.rb) - 面接対策生成
- [app/services/question_answer_scoring_service.rb](../app/services/question_answer_scoring_service.rb) - 回答採点
- [app/services/casual_interview_note_service.rb](../app/services/casual_interview_note_service.rb) - カジュアル面談ノート生成
- [app/services/job_description_fetcher_service.rb](../app/services/job_description_fetcher_service.rb) - 求人情報取得

## セットアップ方法

### 1. Gemのインストール

```bash
docker-compose exec web bundle install
```

これにより以下のgemがインストールされます：
- `openai` (~> 0.23) - OpenAI API用
- `gemini-ai` (~> 4.2) - Google Gemini API用

### 2. 環境変数の設定

`.env`ファイルを編集してAPIキーとプロバイダーを設定します。

#### パターンA: OpenAIのみ使用（デフォルト）

```.env
OPENAI_API_KEY=sk-your-openai-api-key
LLM_PROVIDER=openai
```

#### パターンB: Geminiのみ使用

```.env
GEMINI_API_KEY=your-gemini-api-key
LLM_PROVIDER=gemini
```

#### パターンC: 両方設定して切り替え

```.env
OPENAI_API_KEY=sk-your-openai-api-key
GEMINI_API_KEY=your-gemini-api-key
LLM_PROVIDER=openai  # または gemini
```

### 3. Dockerコンテナの再起動

環境変数を変更したら、コンテナを再起動します：

```bash
docker-compose down
docker-compose up
```

## プロバイダーの切り替え

### 実行時に切り替える

環境変数を変更せずに一時的に切り替えることもできます：

```bash
# OpenAIで実行
docker-compose exec web bash -c "LLM_PROVIDER=openai rails console"

# Geminiで実行
docker-compose exec web bash -c "LLM_PROVIDER=gemini rails console"
```

### Rails consoleでテスト

```ruby
# OpenAIクライアント
client = LlmClient.new(provider: "openai")
response = client.chat(
  system: "あなたはアシスタントです",
  user: "こんにちは",
  temperature: 0.5
)
puts response.content

# Geminiクライアント
client = LlmClient.new(provider: "gemini")
response = client.chat(
  system: "あなたはアシスタントです",
  user: "こんにちは",
  temperature: 0.5
)
puts response.content
```

## モデル設定

### デフォルトモデル

- **OpenAI**: `gpt-4o-mini`
- **Gemini**: `gemini-2.5-flash`

### モデルの変更

`LlmClient`の`default_model`メソッドを編集してデフォルトモデルを変更できます：

```ruby
# app/services/llm_client.rb
def default_model
  case @provider
  when "openai"
    "gpt-4o"  # gpt-4o-mini から変更
  when "gemini"
    "gemini-1.5-pro"  # gemini-2.5-flash から変更
  end
end
```

## テスト

### テストの実行

既存のテストはすべてOpenAI APIのモックを使用しています：

```bash
docker-compose exec web bundle exec rspec
```

### LlmClientのテスト

```bash
docker-compose exec web bundle exec rspec spec/services/llm_client_spec.rb
```

### プロンプト検証テスト

プロンプト検証テストは、デフォルトでは環境変数`LLM_PROVIDER`に従います：

```bash
# OpenAIでテスト
docker-compose exec web bash -c "LLM_PROVIDER=openai RUN_PROMPT_TESTS=true bundle exec rspec spec/services/*_prompt_spec.rb"

# Geminiでテスト
docker-compose exec web bash -c "LLM_PROVIDER=gemini RUN_PROMPT_TESTS=true bundle exec rspec spec/services/*_prompt_spec.rb"
```

**注意**: 初回実行時は実際のAPIを呼び出します。VCRカセットを削除して再記録する場合も同様です。

## トラブルシューティング

### OpenAI APIエラー

```
LlmClient::LlmError: OpenAI API error: ...
```

**対処法:**
1. `OPENAI_API_KEY`が正しく設定されているか確認
2. APIキーに十分なクレジットがあるか確認
3. ネットワーク接続を確認

### Gemini APIエラー

```
LlmClient::ConfigurationError: GEMINI_API_KEY is not set
```

**対処法:**
1. `.env`ファイルに`GEMINI_API_KEY`を追加
2. Dockerコンテナを再起動

```
LlmClient::LlmError: Gemini API error: ...
```

**対処法:**
1. Gemini API keyが有効か確認（https://makersuite.google.com/app/apikey）
2. APIの使用制限に達していないか確認
3. モデル名が正しいか確認

### レスポンス形式の違い

OpenAIとGeminiでレスポンス形式が異なる場合があります。

**OpenAIの特徴:**
- JSON出力が比較的安定
- 指示通りのフォーマットに従いやすい

**Geminiの特徴:**
- 出力がより自然言語的
- JSON出力時に余分なテキストが含まれることがある

**対処法:**
プロンプトを調整するか、パース処理を強化する：

```ruby
# すでに実装済み
json_string = content.gsub(/\A```json|```|\A```|\Z```/m, "").strip
```

## パフォーマンス比較

| 項目 | OpenAI GPT-4o-mini | Google Gemini 2.0 Flash |
|------|-------------------|------------------------|
| 速度 | 中速 | 高速 |
| コスト | 中 | 低 |
| 品質 | 高 | 高 |
| JSON出力 | 安定 | やや不安定 |

## ベストプラクティス

1. **開発環境**: OpenAIを使用（安定性重視）
2. **本番環境**: コストと速度を考慮してGeminiも検討
3. **テスト**: 両方のプロバイダーでテストして互換性を確認
4. **監視**: エラーログとレスポンス品質を継続的に監視

## 移行チェックリスト

- [ ] gemini-ai gemのインストール
- [ ] GEMINI_API_KEYの取得と設定
- [ ] LLM_PROVIDERの設定
- [ ] Dockerコンテナの再起動
- [ ] Rails consoleでの動作確認
- [ ] 既存テストの実行
- [ ] プロンプト検証テストの実行（両プロバイダー）
- [ ] 本番環境への反映（段階的に）

## サポート

問題が発生した場合は、以下を確認してください：

1. ログファイル: `log/development.log` または `log/production.log`
2. エラーメッセージ
3. 使用しているモデル名とプロバイダー
4. APIキーの有効性

詳細は[LlmClient](../app/services/llm_client.rb)のコードを参照してください。
