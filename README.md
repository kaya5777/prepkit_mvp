# PrepKit MVP - 面接対策ノート生成アプリ

求人票を入力するだけで、AIが面接対策に必要な情報を自動生成するWebアプリケーションです。

## 特徴

- **想定質問の自動生成**: 求人票から技術質問と行動面接質問を生成
- **質問の意図分析**: 各質問で面接官が本当に知りたいことを解説
- **レベル別回答ポイント**: 募集職種（Junior/Senior/EM/Tech Lead等）に応じた回答のポイントを提示
- **逆質問のアドバイス**: 募集職種に合わせた効果的な逆質問の仕方をアドバイス
- **技術チェックリスト**: 面接前に確認すべき技術項目をリスト化
- **URL自動取得**: 求人票のURLを入力すると自動で内容を取得（求人情報のみを抽出）
- **履歴管理**: 過去の面接対策ノートを保存・編集・検索

## 技術スタック

- **Ruby**: 3.2.8
- **Rails**: 7.2.0
- **Database**: PostgreSQL 15
- **Frontend**: Tailwind CSS 4.1.13
- **AI**: OpenAI GPT-4o-mini
- **Container**: Docker & Docker Compose
- **Testing**: RSpec, SimpleCov, WebMock, VCR
- **Code Quality**: Rubocop, Brakeman

## セットアップ

### 前提条件

- Docker & Docker Compose がインストールされていること
- OpenAI API キーを取得していること

### 環境変数の設定

1. `.env`ファイルを作成:
```bash
touch .env
```

2. OpenAI API キーを設定:
```bash
echo "OPENAI_API_KEY=sk-your-api-key-here" >> .env
```

### アプリケーションの起動

1. Dockerコンテナをビルド・起動:
```bash
docker-compose up --build
```

2. データベースのセットアップ（初回のみ）:
```bash
docker-compose exec web rails db:create db:migrate
```

3. ブラウザで `http://localhost:3000` を開く

### 開発用コマンド

```bash
# テスト実行
docker-compose exec web bundle exec rspec

# Rubocop実行
docker-compose exec web bundle exec rubocop

# Tailwind CSSのビルド
docker-compose exec web bundle exec rails tailwindcss:build

# Rails console
docker-compose exec web rails console

# ログ確認
docker-compose logs web -f
```

## 使い方

1. **面接対策ノートの作成**
   - トップページで求人票または求人票のURLを入力
   - 「想定質問を生成」ボタンをクリック
   - AIが30秒〜1分程度で面接対策ノートを生成

2. **履歴の確認**
   - サイドバーの「履歴」から過去の面接対策ノートを確認
   - 会社名や日付で検索可能

3. **編集・削除**
   - 各履歴の詳細ページから編集・削除が可能
   - メモ欄に自分の振り返りを追加可能

## プロジェクト構成

```
prepkit_mvp/
├── app/
│   ├── controllers/         # コントローラー
│   ├── models/              # モデル
│   ├── views/               # ビュー（ERB）
│   ├── services/            # サービスオブジェクト
│   │   ├── interview_kit_generator_service.rb  # AI生成ロジック
│   │   └── job_description_fetcher_service.rb  # URL取得ロジック
│   ├── presenters/          # プレゼンター
│   └── assets/
│       └── tailwind/        # Tailwind CSS設定
├── spec/                    # RSpecテスト
├── docker-compose.yml       # Docker設定
├── Dockerfile              # Dockerイメージ設定
└── README.md               # このファイル
```

## テスト

- テストカバレッジ: 約50%
- RSpec + SimpleCov でテストとカバレッジを測定
- WebMock + VCR で外部API呼び出しをモック化

```bash
# 全テスト実行
docker-compose exec web bundle exec rspec

# 特定のテスト実行
docker-compose exec web bundle exec rspec spec/services/interview_kit_generator_service_spec.rb
```

## ライセンス

MIT License
