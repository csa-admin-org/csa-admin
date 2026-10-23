# frozen_string_literal: true

require "test_helper"

class Notification::InvoiceOverdueNoticeTest < ActiveSupport::TestCase
  test "staggers per-invoice jobs one second apart" do
    open_invoices = Invoice.open.order(:id).to_a
    assert open_invoices.many?, "Test requires more than one open invoice"

    freeze_time do
      Current.org.stub(:send_invoice_overdue_notice?, true) do
        Notification::InvoiceOverdueNotice.notify
      end

      jobs = enqueued_jobs.select { |job| job["job_class"] == "Billing::InvoiceOverdueNoticeJob" }
      assert_equal open_invoices.size, jobs.size

      jobs.each_with_index do |job, index|
        assert_in_delta index.seconds.from_now.to_f, job[:at].to_f, 0.001
      end
    end
  end
end
