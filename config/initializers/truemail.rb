# frozen_string_literal: true

Truemail.configure do |config|
  # Required parameter. Must be an existing email on behalf of which verification will be performed
  config.verifier_email = "info@acp-admin.ch"

  # Optional parameter. You can predefine default validation type for
  # Truemail.validate('email@email.com') call without with-parameter
  # Available validation types: :regex, :mx, :mx_blacklist, :smtp
  config.default_validation_type = Rails.env.test? ? :regex : :mx
end
