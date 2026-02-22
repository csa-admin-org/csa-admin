# frozen_string_literal: true

class DemoMailInterceptor
  ALLOWED_TAGS = %w[
    admin-invitation
    session-admin
  ].freeze

  def self.delivering_email(message)
    return unless Tenant.demo?
    return if allowed_email?(message)

    message.perform_deliveries = false
  end

  def self.allowed_email?(message)
    tag = message[:tag]&.to_s
    ALLOWED_TAGS.include?(tag)
  end

  private_class_method :allowed_email?
end
