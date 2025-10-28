FROM ruby:3.2.8

# 必要なライブラリをインストール
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

WORKDIR /app

# Gemfileを先にコピーしてbundle install（キャッシュ効かせる）
COPY Gemfile Gemfile.lock ./
RUN bundle install

# アプリ全体をコピー
COPY . .

# Tailwind CSSとアセットをビルド
RUN bundle exec rails tailwindcss:build
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# エントリーポイントスクリプトをコピーして実行権限を付与
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# ポート設定
EXPOSE 3000

# エントリーポイントを設定
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Railsサーバ起動
CMD ["sh", "-c", "bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0"]
