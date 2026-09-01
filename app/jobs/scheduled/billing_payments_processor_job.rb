# frozen_string_literal: true

require "net/http"

module Scheduled
  class BillingPaymentsProcessorJob < BaseJob
    # Must stay on the subclass: ActiveJob matches retry_on last-defined-first, so
    # this wins over BaseJob's retry_on Exception (short polynomial backoff).
    retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 20.minutes, attempts: 5 do |_job, _error|
      # The next daily import will retrieve any payments missed during the outage.
    end

    def perform
      Billing::PaymentsProcessor.retrieve_and_process!
    end
  end
end
