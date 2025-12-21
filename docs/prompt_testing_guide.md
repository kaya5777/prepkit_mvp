# プロンプトテスト運用ガイド

## 重要な注意事項

### VCRの制限について

**VCRは「プロンプト変更の自動検出」はできません。**

VCRは以下のように動作します：

1. 初回実行時：実際にAPIを呼び出し、レスポンスを記録
2. 2回目以降：記録されたレスポンスを再生（APIを呼ばない）
3. プロンプト変更時：**手動でカセットを削除しない限り、古いレスポンスを使い続ける**

### プロンプト変更時の必須手順

```bash
# 1. カセットを削除（最重要！）
docker-compose exec web rm -rf spec/fixtures/vcr_cassettes/job_match_analysis_prompt_tests
docker-compose exec web rm -rf spec/fixtures/vcr_cassettes/resume_analysis_prompt_tests

# 2. テストを再実行
docker-compose exec web bash -c "RUN_PROMPT_TESTS=true bundle exec rspec spec/services/*_prompt_spec.rb"

# 3. 結果を確認
# - 成功 → プロンプト変更OK
# - 失敗 → 採点基準が変わったので、期待値を調整するかプロンプトを修正
```

**この手順を忘れると、プロンプトを変更してもテストはパスし続けます（デグレ検出できない）**

## テストデータの精度について

### 期待値の設定方針

テストの期待値（「このケースなら90点以上」など）は、**理想的な採点基準**です。

しかし、LLMの採点は以下の理由で変動します：

1. **温度設定（temperature）**: 0.5に設定しているため、多少のランダム性がある
2. **プロンプトの解釈**: 同じプロンプトでもLLMの解釈が微妙に変わる
3. **入力データの微妙な違い**: テストと本番で前提条件が異なる可能性

### 期待値の調整基準

| ケース | 期待スコア | 許容範囲 | 備考 |
|--------|-----------|---------|------|
| S判定 | 90-100点 | 85-100点 | ±5点の誤差は許容 |
| A判定 | 80-89点 | 75-89点 | ±5点の誤差は許容 |
| B判定 | 70-79点 | 65-79点 | ±5点の誤差は許容 |
| C判定 | 60-69点 | 55-69点 | ±5点の誤差は許容 |
| D判定 | 0-59点 | 0-59点 | - |

### S判定で85点になった場合の対処

以下のいずれかを選択：

#### オプション1: 許容範囲として認める（推奨）

```ruby
# テストを修正
expect(result.match_score).to be >= 90  # 変更前
expect(result.match_score).to be >= 85  # 変更後（±5点の誤差を許容）
```

#### オプション2: プロンプトを調整して90点以上にする

```ruby
# app/services/job_match_analysis_service.rb
def system_prompt
  <<~PROMPT
    # 以下を追加
    【スコアリングの注意】
    - 必須要件を完全に満たし、歓迎要件も複数満たす場合は90点以上としてください
  PROMPT
end
```

#### オプション3: テストデータを充実させる

```ruby
# より明確にS判定になるデータに変更
resume = create_resume_with_content(<<~TEXT)
  【職務経歴】
  Rails エンジニア、実務経験10年  # 7年→10年に増やす

  【主要実績】
  ・月間1000万PVのECサイトを開発  # 500万→1000万に増やす
  # ... 以下省略
TEXT
```

## デバッグ方法

### 実際のスコアを確認する

```bash
# デバッグヘルパーを使用
docker-compose exec web rails console

# 以下を実行
load 'spec/services/prompt_test_debug_helper.rb'
PromptTestDebugHelper.debug_perfect_match_case
```

### プロンプトの効果を検証する

1. カセットを削除
2. テストを複数回実行
3. スコアの変動を確認

```bash
# 3回実行してスコアの変動を確認
for i in {1..3}; do
  echo "=== 実行 $i 回目 ==="
  docker-compose exec web bash -c "RUN_PROMPT_TESTS=true bundle exec rspec spec/services/job_match_analysis_service_prompt_spec.rb:20"
  docker-compose exec web rm -rf spec/fixtures/vcr_cassettes/job_match_analysis_prompt_tests/perfect_match.yml
done
```

## テストの限界

### このテストでできること

- ✅ プロンプト変更による**大きな**デグレの検出（90点→60点など）
- ✅ 異なるケース間の相対的な採点順序の検証（S判定 > A判定 > B判定）
- ✅ 回帰テストのベースライン作成

### このテストでできないこと

- ❌ ±5点レベルの細かい採点精度の保証
- ❌ プロンプト変更の自動検出（手動削除が必要）
- ❌ LLMの内部動作の検証

## ベストプラクティス

### 1. プロンプト変更時は必ずカセット削除

```bash
# .git/hooks/pre-commit に追加することを推奨
if git diff --cached --name-only | grep -q "app/services.*_service.rb"; then
  echo "警告: サービスファイルが変更されています"
  echo "プロンプトを変更した場合は、VCRカセットを削除してテストを再実行してください："
  echo "  rm -rf spec/fixtures/vcr_cassettes/*_prompt_tests"
  echo "  RUN_PROMPT_TESTS=true bundle exec rspec spec/services/*_prompt_spec.rb"
fi
```

### 2. 期待値には幅を持たせる

```ruby
# 厳格すぎる（非推奨）
expect(result.match_score).to eq(90)

# 適度な幅を持たせる（推奨）
expect(result.match_score).to be_between(85, 95)

# さらに安全
expect(result.match_score).to be >= 85
expect(result.match_rank).to be_in(["S", "A"])  # S判定期待だがAも許容
```

### 3. 定期的にカセットを再生成

```bash
# 月1回程度、全カセットを削除して再生成
rm -rf spec/fixtures/vcr_cassettes/*_prompt_tests
RUN_PROMPT_TESTS=true bundle exec rspec spec/services/*_prompt_spec.rb
```

これにより、OpenAI APIのモデル更新による変化も検出できます。

## まとめ

プロンプトテストは**完璧な自動検出ツールではなく、手動運用を前提としたリグレッションテストツール**です。

正しく使えば：
- プロンプト変更による大きなデグレを検出できる
- 採点基準の一貫性を保てる
- 安心してプロンプトを改善できる

ただし：
- カセットの手動削除が必須
- ±5点程度の誤差は許容する必要がある
- 定期的な再検証が推奨される
