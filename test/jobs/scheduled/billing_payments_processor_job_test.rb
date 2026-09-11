# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Scheduled::BillingPaymentsProcessorJobTest < ActiveJob::TestCase
  test "retries HTTP timeouts every 20 minutes then tags once and discards" do
    recorder = ErrorRecorder.new
    tagged = []
    attempts = 0
    import = -> {
      attempts += 1
      raise Net::ReadTimeout
    }
    capture_tags = ->(tags = {}) { tagged << tags.stringify_keys }

    travel_to Time.zone.local(2026, 7, 27, 4) do
      Billing::PaymentsProcessor.stub(:retrieve_and_process!, import) do
        Appsignal.stub(:add_tags, capture_tags) do
          with_rails_error(recorder) do
            Scheduled::BillingPaymentsProcessorJob.perform_later
            perform_enqueued_jobs

            retry_delay = enqueued_jobs.sole.fetch(:at) - Time.current.to_f
            assert_operator retry_delay, :>=, 20.minutes.to_i
            assert_operator retry_delay, :<=, 23.minutes.to_i
            assert_empty recorder.reports
            assert_empty tagged

            3.times { perform_enqueued_jobs }
            assert_empty recorder.reports
            assert_empty tagged
            assert_enqueued_jobs 1

            perform_enqueued_jobs
          end
        end
      end
    end

    assert_equal 5, attempts
    assert_no_enqueued_jobs
    assert_empty recorder.reports
    assert_equal 1, tagged.size
    assert_equal "acme", tagged.first["tenant"]
    assert_equal 5, tagged.first["executions"]
    assert_equal "payment_import", tagged.first["operation_kind"]
  end
end
