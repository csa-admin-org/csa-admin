# frozen_string_literal: true

source "https://rubygems.org"

gem "rails", "~> 8.1"

gem "bootsnap", require: false
gem "thruster", require: false
gem "kamal", require: false

gem "propshaft"
gem "puma"

gem "sqlite3"
gem "sqlean"

gem "aws-sdk-s3"

gem "appsignal"
gem "lograge"

gem "bcrypt"
gem "date_validator"

gem "rails-i18n"
gem "i18n-backend-side_by_side"

gem "rack-status"
gem "rack-cors"

gem "phony_rails"
gem "truemail"
gem "tod"
gem "discard"

gem "activeadmin", "~> 4.0.0.beta17"
gem "cancancan"
gem "acts_as_list"

gem "simple_form"

gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "action_text-trix"
gem "inline_svg"

gem "cld", require: false

gem "solid_queue"
gem "mission_control-jobs"

gem "faraday", require: false
gem "faraday-cookie_jar", require: false

gem "icalendar", require: false
gem "image_processing"
# https://github.com/prawnpdf/ttfunk/issues/102
gem "prawn", "2.4.0"
gem "ttfunk", "1.7.0", require: false
gem "prawn-table", require: false
gem "prawn-svg", require: false
gem "hexapdf", require: false
gem "public_suffix", require: false
gem "rubyXL", require: false
gem "rexml"
# https://github.com/weshatheleopard/rubyXL/issues/473
gem "rubyzip", "~> 2.4", require: false
gem "parallel", require: false

gem "postmark-rails"
gem "premailer-rails"
gem "liquid"

gem "camt_parser", require: false
gem "cmxl", require: false
gem "epics", require: false
gem "girocode", require: false # EPC QR code
gem "sepa_king", require: false
gem "rqrcode", require: false
gem "countries"
gem "user_agent_parser", require: false

gem "kramdown", require: false
gem "nokogiri", require: false

gem "faker", require: false
gem "cloudflare", require: false
gem "cloudflare-rails", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  gem "dotenv"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  gem "bundle-audit"

  gem "letter_opener"
  gem "terminal-table", require: false

  gem "ruby-lsp-rails", require: false

  gem "rubocop-rails-omakase", require: false
  gem "rubocop-erb", require: false
  gem "rubocop-minitest", require: false

  gem "herb", require: false
  gem "htmlbeautifier", require: false

  gem "brakeman", require: false
end

group :test do
  gem "capybara"
  gem "capybara-email"
  gem "pdf-inspector", require: "pdf/inspector"
  gem "minitest-difftastic"
end
