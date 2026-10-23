# frozen_string_literal: true

require "test_helper"

module Billing
  class InvoiceOverdueNoticeJobTest < ActiveJob::TestCase
    test "retries on StatementTimeout instead of swallowing it" do
      invoice = invoices(:annual_fee)
      invoice.update!(sent_at: 40.days.ago)

      freeze_time do
        InvoiceOverdueNotice.stub(:deliver, ->(*) { raise ActiveRecord::StatementTimeout }) do
          InvoiceOverdueNoticeJob.perform_later(invoice)

          perform_enqueued_jobs only: InvoiceOverdueNoticeJob, at: Time.current
        end

        assert_enqueued_with job: InvoiceOverdueNoticeJob, at: 5.seconds.from_now
      end
    end
  end
end
