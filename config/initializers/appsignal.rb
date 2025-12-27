# frozen_string_literal: true

Appsignal.configure do |config|
  config.push_api_key = Rails.application.credentials.appsignal_push_api_key
  config.name = "CSA Admin"
  config.revision = ENV["GIT_REV"] if ENV["GIT_REV"].present?

  config.ignore_errors = [
    "ActiveRecord::RecordNotFound",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::BadRequest"
  ]

  config.active = Rails.env.production?
  config.running_in_container = true if Rails.env.production?

  # Report events from Rails 8.1's Structured Event Reporting (Rails.event.notify)
  # as logs to AppSignal. Added in appsignal gem 4.8.0.
  config.enable_active_support_event_log_reporter = true
end
