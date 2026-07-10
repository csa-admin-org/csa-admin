# frozen_string_literal: true

module Scheduled
  class EBICSOnboardingFinalizationJob < BaseJob
    def perform
      BankConnection::FinalizationNotification.dispatch_pending!

      eligible_connections.find_each do |connection|
        next unless hia_submitted?(connection)

        Billing::EBICS::Onboarding.new(connection: connection).check_finalization!
      end
    end

    private

    def eligible_connections
      BankConnection.where(
        provider: "ebics",
        active: false,
        state: "waiting_for_bank")
    end


    def hia_submitted?(connection)
      onboarding_status(connection)["hia_submitted_at"].present?
    end

    def onboarding_status(connection)
      connection.status_details.to_h.dig("onboarding").to_h.deep_stringify_keys
    end
  end
end
