# frozen_string_literal: true

require "test_helper"

class Billing::MissingActivityParticipationsInvoicerJobTest < ActiveJob::TestCase
  def perform(membership)
    perform_enqueued_jobs do
      Billing::MissingActivityParticipationsInvoicerJob.perform_later(membership)
    end
  end

  test "noop if no activity price" do
    org(activity_price: 0)
    membership = memberships(:jane)

    assert_no_difference "Invoice.count" do
      perform(membership)
    end
  end

  test "noop if no missing activity participations" do
    membership = memberships(:jane)
    membership.update!(activity_participations_demanded_annually: 0)

    assert_no_difference "Invoice.count" do
      perform(membership)
    end
  end

  test "create invoice and send invoice" do
    mail_templates(:invoice_created)
    membership = memberships(:jane)
    membership.update!(activity_participations_demanded_annually: 2)

    assert_difference [ "Invoice.count", "InvoiceMailer.deliveries.size" ], 1 do
      assert_changes -> { membership.reload.activity_participations_missing }, to: 0 do
        perform(membership)
      end
    end

    invoice = membership.member.invoices.last
    assert_equal Date.today, invoice.date
    assert_equal 2, invoice.missing_activity_participations_count
    assert_equal membership.fiscal_year, invoice.missing_activity_participations_fiscal_year
    assert_equal "ActivityParticipation", invoice.entity_type
    assert_nil invoice.entity_id
    assert_equal 2 * 50, invoice.amount
    assert invoice.sent?
  end

  test "create invoice for previous year membership" do
    travel_to "2025-01-01"

    membership = memberships(:jane)
    membership.update!(activity_participations_demanded_annually: 2)

    assert_difference "Invoice.count", 1 do
      perform(membership)
    end

    invoice = membership.member.invoices.last
    assert_equal Date.today, invoice.date
    assert_equal FiscalYear.for(2024), invoice.missing_activity_participations_fiscal_year
    assert_equal "ActivityParticipation", invoice.entity_type
    assert_nil invoice.entity_id
    assert invoice.sent?
  end
end
