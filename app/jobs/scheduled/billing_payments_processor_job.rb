# frozen_string_literal: true

module Scheduled
  class BillingPaymentsProcessorJob < BaseJob
    def perform
      Billing::PaymentsProcessor.retrieve_and_process!
    end
  end
end
