# frozen_string_literal: true

require "test_helper"

class Scheduled::BillingSEPADirectDebitOrdersUploaderJobTest < ActiveJob::TestCase
  setup do
    BankConnection.delete_all
  end

  test "enqueues SEPA direct debit order uploader job only for qualifying invoices" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    create_mock_bank_connection

    assert Current.org.sepa_creditor_identifier?
    assert Current.org.bank_connection?

    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload

    create_annual_fee_invoice(member: members(:john))

    closed_sepa_invoice = create_annual_fee_invoice(member: member)
    closed_sepa_invoice.update!(state: "closed")

    create_annual_fee_invoice(member: member)

    recent_sent_sepa_invoice = create_annual_fee_invoice(member: member)
    recent_sent_sepa_invoice.update!(sent_at: 1.day.ago)

    uploaded_sepa_invoice = create_annual_fee_invoice(member: member)
    uploaded_sepa_invoice.update!(sent_at: 5.days.ago, sepa_direct_debit_order_uploaded_at: 1.day.ago)

    qualifying_invoice = create_annual_fee_invoice(member: member)
    qualifying_invoice.update!(sent_at: 3.days.ago)

    assert_enqueued_jobs 1, only: Billing::SEPADirectDebitOrderUploaderJob do
      perform_enqueued_jobs only: Scheduled::BillingSEPADirectDebitOrdersUploaderJob do
        Scheduled::BillingSEPADirectDebitOrdersUploaderJob.perform_later
      end
    end

    assert_changes -> { qualifying_invoice.reload.sepa_direct_debit_order_uploaded? } do
      perform_enqueued_jobs
    end
    assert_equal "N042", qualifying_invoice.sepa_direct_debit_order_id
  end

  test "reports uploadable SEPA invoices stuck past the automatic upload window" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    create_mock_bank_connection
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)
    invoice.update!(sent_at: 5.days.ago)
    error = ErrorRecorder.new

    with_rails_error(error) do
      perform_enqueued_jobs only: Scheduled::BillingSEPADirectDebitOrdersUploaderJob do
        Scheduled::BillingSEPADirectDebitOrdersUploaderJob.perform_later
      end
    end

    message, context = error.unexpected_errors.first
    assert_equal "SEPA direct debit orders stuck before upload", message
    assert_equal 1, context.fetch("invoices_count")
    assert_equal [ invoice.id ], context.fetch("invoice_ids")
    assert context.fetch("oldest_sent_at")
  end

  test "does nothing if org has no sepa_creditor_identifier" do
    german_org(sepa_creditor_identifier: nil)
    create_mock_bank_connection
    assert_not Current.org.sepa_creditor_identifier?
    assert Current.org.bank_connection?

    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload

    qualifying_invoice = create_annual_fee_invoice(member: member)
    qualifying_invoice.update!(sent_at: 5.days.ago)

    assert_no_enqueued_jobs only: Billing::SEPADirectDebitOrderUploaderJob do
      perform_enqueued_jobs only: Scheduled::BillingSEPADirectDebitOrdersUploaderJob do
        Scheduled::BillingSEPADirectDebitOrdersUploaderJob.perform_later
      end
    end
  end

  test "does nothing if org has no bank_connection" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    assert Current.org.sepa_creditor_identifier?
    assert_not Current.org.bank_connection?

    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload

    qualifying_invoice = create_annual_fee_invoice(member: member)
    qualifying_invoice.update!(sent_at: 5.days.ago)

    assert_no_enqueued_jobs only: Billing::SEPADirectDebitOrderUploaderJob do
      perform_enqueued_jobs only: Scheduled::BillingSEPADirectDebitOrdersUploaderJob do
        Scheduled::BillingSEPADirectDebitOrdersUploaderJob.perform_later
      end
    end
  end

  private

  def create_mock_bank_connection
    BankConnection.create!(
      provider: "mock",
      active: true,
      state: "ready",
      credentials: { password: "secret" })
  end
end
