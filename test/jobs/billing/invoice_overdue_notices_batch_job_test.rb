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

    test "staggers InvoiceOverdueNoticeJob one second apart" do
      open_invoices = Invoice.open.order(:id).to_a
      assert open_invoices.many?, "Test requires more than one open invoice"

      freeze_time do
        perform_enqueued_jobs only: InvoiceOverdueNoticesBatchJob do
          InvoiceOverdueNoticesBatchJob.perform_later
        end

        jobs = enqueued_jobs.select { |job| job["job_class"] == "Billing::InvoiceOverdueNoticeJob" }
        assert_equal open_invoices.size, jobs.size

        jobs.each_with_index do |job, index|
          assert_in_delta index.seconds.from_now.to_f, job[:at].to_f, 0.001
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
