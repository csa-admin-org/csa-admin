# frozen_string_literal: true

require "net/http"

module Scheduled
  class BillingPaymentsProcessorJob < BaseJob
    # Must stay on the subclass: ActiveJob matches retry_on last-defined-first, so
    # this wins over BaseJob's retry_on Exception (short polynomial backoff).
    # Mid-retries stay quiet: report: false (ActiveJob default) plus
    # activejob_report_errors = "discard" (AppSignal only set_error on after_discard).
    retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 20.minutes, attempts: 5, report: false do |job, _error|
      # Discard after the last attempt so the next daily import can catch up.
      # AppSignal's after_discard hook reports that exhausted timeout once;
      # only enrich the current transaction so that sample is useful.
      job.tag_exhausted_timeout
    end

    def perform
      Billing::PaymentsProcessor.retrieve_and_process!
    end

    def tag_exhausted_timeout
      # retry_on runs outside TenantContext's around_perform, so re-enter the
      # serialized tenant before reading Current.org / bank connection.
      with_context { tag_timeout_in_tenant }
    end

    private

    def tag_timeout_in_tenant
      context = Billing::EBICS::SafeContext.build(
        connection: Current.org.active_bank_connection,
        operation_kind: "payment_import",
        executions: executions)
      Appsignal.add_tags(**context)
    end
  end
end
