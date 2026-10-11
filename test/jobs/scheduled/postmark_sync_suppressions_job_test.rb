# frozen_string_literal: true

require "test_helper"

class Scheduled::PostmarkSyncSuppressionsJobTest < ActiveJob::TestCase
  test "retries Postmark internal server errors then discards" do
    attempts = 0
    sync = -> {
      attempts += 1
      raise Postmark::InternalServerError
    }

    EmailSuppression.stub(:sync_postmark!, sync) do
      Scheduled::PostmarkSyncSuppressionsJob.perform_later
      perform_enqueued_jobs

      4.times { perform_enqueued_jobs }
    end

    assert_equal 5, attempts
    assert_no_enqueued_jobs
  end
end
