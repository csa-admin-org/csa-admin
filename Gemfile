# frozen_string_literal: true

source "https://rubygems.org", cooldown: 3

# 8.2 is unreleased. Pin the revision so `bundle update` does not float main.
# Bump this ref to upgrade.
gem "rails", github: "rails/rails", ref: "f39c8aa"

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
# Published 7.0.0 still caps Rails at < 8.2. Main allows < 8.3.
# require: false — the Railtie is not loaded in the web process (hostname.rake only).
gem "cloudflare-rails", github: "modosc/cloudflare-rails", require: false

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
gem "geocoder"
gem "rack-status"
gem "rack-cors"
gem "faraday", require: false
gem "terminal-table", require: false

# Admin and UI
gem "activeadmin", "~> 4.0.0.beta23"
gem "cancancan"
gem "acts_as_list"
gem "simple_form"
gem "reactionview"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
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
gem "ruby-vips"
gem "rexml"
gem "rubyzip", require: false
gem "parallel", require: false

# Email
gem "postmark-rails"
gem "premailer-rails"
gem "liquid"

# Billing
gem "cmxl", require: false
gem "girocode", require: false # EPC QR code
gem "iban-tools", require: false
gem "rqrcode", require: false
gem "sepa_file_parser", require: false

# Parsing and Data
gem "user_agent_parser", require: false
gem "kramdown", require: false
gem "nokogiri", require: false
gem "faker", require: false

group :development, :test do
  # Debugging
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
end

group :development do
  # Console and Debugging
  gem "web-console"

  # Email Testing
  gem "letter_opener"

  # Code Quality
  gem "ruby-lsp-rails", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-erb", require: false
  gem "rubocop-minitest", require: false
  gem "herb", require: false

  # Security
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end

group :test do
  # Integration Testing
  gem "capybara"
  gem "capybara-email"

  # HTTP Mocking
  gem "webmock"

  # PDF Testing
  gem "pdf-inspector", require: "pdf/inspector"

  # Test Output
  gem "minitest-difftastic"

  # Stubs / Mocks
  gem "minitest-mock"
end
