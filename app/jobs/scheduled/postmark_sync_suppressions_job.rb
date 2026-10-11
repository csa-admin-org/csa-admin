# frozen_string_literal: true

require "net/http"

module Scheduled
  class PostmarkSyncSuppressionsJob < BaseJob
    retry_on Postmark::InternalServerError, Postmark::TimeoutError,
      Postmark::HttpClientError, Postmark::UnexpectedHttpResponseError,
      Net::OpenTimeout, Net::ReadTimeout,
      wait: :polynomially_longer, attempts: 3 do |_job, _error|
    end

    def perform
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
    end
  end
end
