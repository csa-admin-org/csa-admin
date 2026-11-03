# frozen_string_literal: true

Appsignal.configure do |config|
  config.push_api_key = Rails.application.credentials.appsignal_push_api_key
  config.name = "CSA Admin"
  config.revision = ENV["GIT_REV"] if ENV["GIT_REV"].present?
  config.activejob_report_errors = "discard"

  config.ignore_errors = [
    "ActiveRecord::RecordNotFound",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::InvalidCrossOriginRequest",
    "ActionController::BadRequest",
    "ActionController::UnknownFormat",
    "ActionDispatch::Http::MimeNegotiation::InvalidType",
    "ActionDispatch::Http::Parameters::ParseError",
    "ActionDispatch::RemoteIp::IpSpoofAttackError"
  ]

  config.active = Rails.env.production?
  config.running_in_container = true if Rails.env.production?

  # Privacy: AppSignal's own filter (exact, case-sensitive key match) applies to
  # background job arguments, request payload/query and other sample data.
  # Rails filter_parameters is partial and does not apply here.
  config.filter_parameters = %w[
    email emails billing_email recipient from to name billing_name
    phones street zip city billing_street billing_zip billing_city
    note food_note delivery_note profession come_from
    iban umr number carpooling_phone carpooling_city
    description details subject html body ref
    token password secret
    From FromName To OriginalRecipient Subject TextBody HtmlBody
    StrippedTextReply FromFull ToFull Headers Attachments Email Name
  ]
  config.send_session_data = false
  config.send_function_parameters = false
  config.request_headers = %w[
    HTTP_ACCEPT HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL
    CONTENT_LENGTH REQUEST_METHOD SERVER_NAME SERVER_PORT SERVER_PROTOCOL
  ]

  # Report events from Rails 8.1's Structured Event Reporting (Rails.event.notify)
  # as logs to AppSignal. Added in appsignal gem 4.8.0.
  config.enable_active_support_event_log_reporter = true
end
