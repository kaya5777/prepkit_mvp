FROM ruby:3.2.8

# 必要なライブラリをインストール
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

WORKDIR /app

# Gemfileを先にコピーしてbundle install（キャッシュ効かせる）
COPY Gemfile Gemfile.lock ./
RUN bundle install

# アプリ全体をコピー
COPY . .

# ポート設定
EXPOSE 3000

# Railsサーバ起動
# CMD ["bin/rails", "server", "-b", "0.0.0.0"]
CMD ["sh", "-c", "bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0"]
