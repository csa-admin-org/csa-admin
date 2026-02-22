# frozen_string_literal: true

require "faraday"

module Scheduled
  class BillingPaymentsProcessorJob < BaseJob
    retry_on Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 5 do |_job, _error|
      # Silently discard, payments will be fetched on the next scheduled run.
    end

    def perform
      Billing::PaymentsProcessor.retrieve_and_process!
    end
  end
end
