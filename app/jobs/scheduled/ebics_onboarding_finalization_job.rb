# frozen_string_literal: true

module Scheduled
  class EBICSOnboardingFinalizationJob < BaseJob
    def perform
      eligible_connections.find_each do |connection|
        next if checked_today?(connection)
        next unless hia_submitted?(connection)

        result = Billing::EBICS::Onboarding.new(connection: connection).check_finalization!
        notify_finalized(connection.reload) if result["finalized"]
      end
    end

    private

    def eligible_connections
      BankConnection.where(
        provider: "ebics",
        active: false,
        state: "waiting_for_bank")
    end

    def checked_today?(connection)
      checked_at = onboarding_status(connection)["last_finalization_check_at"]
      checked_at.present? && Time.iso8601(checked_at).to_date >= Time.current.to_date
    rescue ArgumentError
      false
    end

    def hia_submitted?(connection)
      onboarding_status(connection)["hia_submitted_at"].present?
    end

    def notify_finalized(connection)
      notify_initiating_admin_finalized(connection)

      EBICSOnboardingMailer
        .with(connection: connection)
        .finalized_notification_email
        .deliver_later
    end

    def notify_initiating_admin_finalized(connection)
      admin = initiating_admin(connection)
      return unless admin

      AdminMailer
        .with(admin: admin, connection: connection)
        .ebics_setup_finalized_email
        .deliver_later
    end

    def initiating_admin(connection)
      status = onboarding_status(connection)
      Admin.find_by(id: status["initiated_by_admin_id"]) ||
        Admin.find_by(email: status["initiated_by_admin_email"])
    end

    def onboarding_status(connection)
      connection.status_details.to_h.dig("onboarding").to_h.deep_stringify_keys
    end
  end
end
