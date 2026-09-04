# frozen_string_literal: true

class BankConnection
  module BAS
    extend ActiveSupport::Concern

    LOGIN_ERROR_CLASS = "Billing::BAS::LoginError"
    UNKNOWN_ERROR_CLASS = "Billing::BAS::UnknownError"

    included do
      attr_accessor :contract_password
    end

    def bas?
      provider == "bas"
    end

    def can_update_bas_password?
      bas? && active? && ready?
    end

    def payment_import_blocked?
      health_status == "errored" && last_error_class == LOGIN_ERROR_CLASS
    end

    def contract_number
      credentials.to_h.stringify_keys["contract_number"]
    end

    def update_bas_password!(password)
      fail ArgumentError, "password required" if password.blank?
      fail "not a BAS connection" unless bas?

      Billing::BAS.new(credentials_with_password(password)).verify_login!

      now = Time.current
      self.credentials = credentials_with_password(password)
      assign_attributes(
        health_status: "healthy",
        last_health_check_at: now,
        last_error_class: nil,
        last_error_message: nil,
        status_details: password_update_status_details(now))
      save!
      Scheduled::BillingPaymentsProcessorJob.perform_later
      self
    end

    def notify_bas_login_error!
      return unless last_error_class == LOGIN_ERROR_CLASS
      return if status_details.to_h.dig("last_error", "notified_at").present?

      Permission.superadmin.admins.find_each do |admin|
        next if EmailSuppression.outbound.active.exists?(email: admin.email)

        AdminMailer.with(admin: admin, connection: self).bas_login_error_email.deliver_later
      end

      update_columns(
        status_details: merged_status_details("last_error", notified_at: Time.current.iso8601),
        updated_at: Time.current)
    end

    def credentials_updated_after?(time)
      updated_at = status_details.to_h["credentials_updated_at"]
      return false if updated_at.blank? || time.blank?

      Time.zone.parse(updated_at.to_s).to_i >= time.to_i
    end

    private

    def credentials_with_password(password)
      credentials.to_h.stringify_keys.merge("contract_password" => password)
    end

    def password_update_status_details(now)
      details = status_details.to_h.deep_stringify_keys
      details["credentials_updated_at"] = now.iso8601
      details.delete("last_error")
      details
    end
  end
end
