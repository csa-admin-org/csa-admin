# frozen_string_literal: true

require "net/http"

module Scheduled
  class BillingPaymentsProcessorJob < BaseJob
    retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 15.minutes, attempts: 5 do |_job, _error|
      # The next daily import will retrieve any payments missed during the outage.
    end

    def perform
      Billing::PaymentsProcessor.retrieve_and_process!
    end
  end
end
