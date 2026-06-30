# frozen_string_literal: true

require "test_helper"

class Scheduled::BillingSEPADirectDebitOrdersUploaderJobTest < ActiveJob::TestCase
  test "enqueues SEPA direct debit order uploader job only for qualifying invoices" do
    german_org(
      sepa_creditor_identifier: "DE98ZZZ09999999999",
      bank_connection_type: "mock",
      bank_credentials: { password: "secret" })

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
    qualifying_invoice.update!(sent_at: 5.days.ago)

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

  test "does nothing if org has no sepa_creditor_identifier" do
    german_org(
      sepa_creditor_identifier: nil,
      bank_connection_type: "mock",
      bank_credentials: { password: "secret" })
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
    german_org(
      sepa_creditor_identifier: "DE98ZZZ09999999999",
      bank_connection_type: nil)
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
end
