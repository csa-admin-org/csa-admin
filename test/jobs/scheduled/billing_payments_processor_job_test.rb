# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Scheduled::BillingPaymentsProcessorJobTest < ActiveJob::TestCase
  test "retries HTTP timeouts every 20 minutes then discards" do
    attempts = 0
    import = -> {
      attempts += 1
      raise Net::ReadTimeout
    }

    travel_to Time.zone.local(2026, 7, 27, 4) do
      Billing::PaymentsProcessor.stub(:retrieve_and_process!, import) do
        Scheduled::BillingPaymentsProcessorJob.perform_later
        perform_enqueued_jobs

        retry_delay = enqueued_jobs.sole.fetch(:at) - Time.current.to_f
        assert_operator retry_delay, :>=, 20.minutes.to_i
        assert_operator retry_delay, :<=, 23.minutes.to_i

        4.times { perform_enqueued_jobs }
      end
    end

    assert_equal 5, attempts
    assert_no_enqueued_jobs
  end
end
