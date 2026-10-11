# frozen_string_literal: true

require "net/http"

module Scheduled
  class PostmarkSyncSuppressionsJob < BaseJob
    # Must stay on the subclass: ActiveJob matches retry_on last-defined-first, so
    # this wins over BaseJob's retry_on Exception (short polynomial backoff).
    retry_on Postmark::InternalServerError, Postmark::TimeoutError,
      Postmark::HttpClientError, Postmark::UnexpectedHttpResponseError,
      Net::OpenTimeout, Net::ReadTimeout,
      wait: :polynomially_longer, attempts: 5 do |_job, _error|
      # The next hourly sync will retrieve any suppressions missed during the outage.
    end

    def perform
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
    end
  end
end
