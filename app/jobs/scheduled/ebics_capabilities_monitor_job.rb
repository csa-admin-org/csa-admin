# frozen_string_literal: true

module Scheduled
  class EBICSCapabilitiesMonitorJob < BaseJob
    def perform
      connection = Current.org.active_bank_connection
      return unless connection&.ebics?

      Billing::EBICS::CapabilitiesMonitor.new(connection: connection).check!
    end
  end
end
