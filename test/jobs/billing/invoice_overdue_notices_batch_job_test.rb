# frozen_string_literal: true

require "test_helper"

module Billing
  class InvoiceOverdueNoticesBatchJobTest < ActiveJob::TestCase
    test "enqueues InvoiceOverdueNoticeJob for each open invoice" do
      open_invoices = Invoice.open.to_a
      assert open_invoices.any?, "Test requires at least one open invoice"

      assert_enqueued_jobs open_invoices.size, only: InvoiceOverdueNoticeJob do
        perform_enqueued_jobs only: InvoiceOverdueNoticesBatchJob do
          InvoiceOverdueNoticesBatchJob.perform_later
        end
      end
    end

    test "does not enqueue jobs for closed invoices" do
      Invoice.open.find_each { |i| i.update_columns(state: "closed") }

      assert_no_enqueued_jobs only: InvoiceOverdueNoticeJob do
        perform_enqueued_jobs only: InvoiceOverdueNoticesBatchJob do
          InvoiceOverdueNoticesBatchJob.perform_later
        end
      end
    end
  end
end
