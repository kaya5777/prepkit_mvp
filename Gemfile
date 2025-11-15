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

group :development, :test do
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.4"
  gem "rubocop", require: false
  gem "rubocop-rails-omakase", require: false
  gem "brakeman", require: false
end

group :test do
  gem "shoulda-matchers", "~> 6.4"
  gem "simplecov", "~> 0.22", require: false
  gem "webmock", "~> 3.23"
  gem "vcr", "~> 6.3"
end

gem "tailwindcss-rails", "~> 4.3"

gem "sprockets-rails", "~> 3.5"
