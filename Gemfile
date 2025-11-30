source "https://rubygems.org"
ruby "3.2.8"

gem "rails", "~> 7.2.0"
gem "puma", "~> 6.0"
gem "sqlite3", "~> 1.4"
gem "openai", "~> 0.23" # simple OpenAI client
gem "bootsnap", ">= 1.4.4", require: false
gem "importmap-rails"
gem "pg"
gem "nokogiri", "~> 1.16"
gem "devise", "~> 4.9"
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-rails_csrf_protection", "~> 1.0"

# 職務経歴書機能用
gem "pdf-reader", "~> 2.12"  # PDF読み取り
gem "docx", "~> 0.8"         # Word読み取り
gem "prawn", "~> 2.4"        # PDF生成
gem "rubyzip", "~> 2.3"      # docx生成用

group :development, :test do
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.4"
  gem "rubocop", require: false
  gem "rubocop-rails-omakase", require: false
  gem "brakeman", require: false
  gem "bullet", "~> 7.2"
end

group :test do
  gem "shoulda-matchers", "~> 7.0"
  gem "simplecov", "~> 0.22", require: false
  gem "webmock", "~> 3.23"
  gem "vcr", "~> 6.3"
  gem "capybara", "~> 3.40"
  gem "selenium-webdriver", "~> 4.25"
  gem "rails-controller-testing", "~> 1.0"
end

gem "tailwindcss-rails", "~> 4.3"

gem "sprockets-rails", "~> 3.5"
