# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "8.0.0.rc2"

gem "bootsnap", require: false
gem "thruster", require: false
gem "propshaft"
gem "puma"
# TODO: remove this dependency, once fully switched to SQLite
gem "pg"

gem "sqlite3"
gem "litestream"

gem "lograge"

gem "bcrypt"
gem "date_validator"
gem "i18n"
gem "i18n-backend-side_by_side"
gem "rails-i18n"

gem "rack-status"
gem "rack-cors"

gem "phony_rails"
gem "truemail"
gem "tod"
gem "discard"

gem "activeadmin", "~> 4.0.0.beta13"
gem "cancancan"
gem "acts_as_list"

gem "simple_form"
gem "inline_svg"
gem "slim"

gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "rails_icons"

gem "cld"

gem "solid_queue", github: "rails/solid_queue", branch: "main"
gem "mission_control-jobs"

gem "faraday"
gem "faraday-cookie_jar"

gem "icalendar"
gem "image_processing"
# https://github.com/prawnpdf/ttfunk/issues/102
gem "prawn", "2.4.0"
gem "ttfunk", "1.7.0"
gem "pdf-core", "0.9.0"
gem "prawn-table"
gem "prawn-svg"
gem "hexapdf"
gem "public_suffix"
gem "rubyXL"
gem "rexml"
gem "rubyzip", require: "zip"
gem "parallel"

gem "postmark-rails"
gem "premailer-rails"
gem "liquid"

gem "camt_parser"
gem "cmxl"
gem "epics"
gem "girocode" # EPC QR code
gem "rqrcode"
gem "countries"
gem "user_agent_parser"

gem "sentry-ruby"
gem "sentry-rails"

gem "kramdown"
gem "nokogiri"

group :development, :test do
  gem "dotenv"
  gem "byebug"
  gem "pdf-inspector", require: "pdf/inspector"
  gem "rspec-rails"
  gem "faker"
  gem "factory_bot_rails"
  gem "brakeman"
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console"
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  # gem 'rack-mini-profiler', '~> 2.0'
  gem "listen"
  gem "letter_opener"

  gem "terminal-table"

  gem "ruby-lsp-rails", require: false
  gem "ruby-lsp-rspec", require: false

  gem "rubocop-rails-omakase", require: false

  gem "prosopite"
  gem "pg_query"
end

group :test do
  gem "launchy"
  gem "capybara"
  gem "capybara-email"
  gem "super_diff"
  gem "test-prof"
end
