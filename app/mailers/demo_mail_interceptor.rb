# frozen_string_literal: true

# Intercepts outgoing emails in demo mode to prevent demo admins from
# spamming real email addresses. Only allows essential authentication
# emails through based on their mail tag:
# - session-member (member login links)
# - session-admin (admin login links)
# - admin-invitation (admin account setup)
#
# All other emails are silently blocked by setting perform_deliveries to false.
#
# Usage: Register in an initializer with
#   ActionMailer::Base.register_interceptor(DemoMailInterceptor)
#
class DemoMailInterceptor
  ALLOWED_TAGS = %w[
    session-member
    session-admin
    admin-invitation
  ].freeze

  def self.delivering_email(message)
    return unless Tenant.demo?
    return if allowed_email?(message)

    # Block the email
    message.perform_deliveries = false
  end

  def self.allowed_email?(message)
    tag = message[:tag]&.to_s
    ALLOWED_TAGS.include?(tag)
  end

  private_class_method :allowed_email?
end
