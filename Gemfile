# frozen_string_literal: true

source "https://rubygems.org"

gem "rails", "~> 8.1"

# Core Framework
gem "bootsnap", require: false
gem "thruster", require: false
gem "kamal", require: false
gem "propshaft"
gem "puma"

# Database and Storage
gem "sqlite3"
gem "sqlean"
gem "aws-sdk-s3"
gem "cloudflare", require: false
gem "cloudflare-rails", require: false

# Monitoring and Security
gem "appsignal"
gem "lograge"
gem "bcrypt"

# Utilities and Validation
gem "countries"
gem "date_validator"
gem "phony_rails"
gem "truemail"
gem "tod"
gem "discard"
gem "rails-i18n"
gem "i18n-backend-side_by_side"
gem "rack-status"
gem "rack-cors"

# Admin and UI
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

# Background Processing
gem "solid_queue"
gem "mission_control-jobs"

# File and Document Processing
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

# Email
gem "postmark-rails"
gem "premailer-rails"
gem "liquid"

# Billing
gem "camt_parser", require: false
gem "cmxl", require: false
gem "epics", require: false
gem "girocode", require: false # EPC QR code
gem "sepa_king", require: false
gem "rqrcode", require: false

# Parsing and Data
gem "user_agent_parser", require: false
gem "kramdown", require: false
gem "nokogiri", require: false
gem "faker", require: false

group :development, :test do
  # Debugging
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Environment Variables
  gem "dotenv"
end

group :development do
  # Console and Debugging
  gem "web-console"

  # Email Testing
  gem "letter_opener"
  gem "terminal-table", require: false

  # Code Quality
  gem "ruby-lsp-rails", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-erb", require: false
  gem "rubocop-minitest", require: false

  # Security
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end

group :test do
  # Integration Testing
  gem "capybara"
  gem "capybara-email"

  # PDF Testing
  gem "pdf-inspector", require: "pdf/inspector"

  # Test Output
  gem "minitest-difftastic"
end
