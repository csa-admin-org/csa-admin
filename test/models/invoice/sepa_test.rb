# frozen_string_literal: true

require "test_helper"

class Invoice::SEPATest < ActiveSupport::TestCase
  test "persisted sepa_mandate on invoice creation" do
    org(
      features: Current.org.features | [ :sepa ],
      country_code: "DE",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: "123",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)

    assert_equal "DE89370400440532013000", invoice.sepa_mandate.iban
    assert_equal "John Doe", invoice.sepa_debtor_name
    assert_equal "123", invoice.sepa_mandate.umr
    assert_equal Date.parse("2024-01-01"), invoice.sepa_mandate.signed_on
    assert invoice.sepa?
  end

  test "persisted sepa_mandate with different billing info" do
    org(
      features: Current.org.features | [ :sepa ],
      country_code: "DE",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: "123",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload
    member.update!(
      different_billing_info: true,
      billing_name: "Acme Corp",
      billing_street: "Billing Street 1",
      billing_city: "Billing City",
      billing_zip: "9999")

    invoice = create_annual_fee_invoice(member: member)

    assert_equal "DE89370400440532013000", invoice.sepa_mandate.iban
    assert_equal "Acme Corp", invoice.sepa_debtor_name
    assert_equal "123", invoice.sepa_mandate.umr
    assert invoice.sepa?
  end

  test "keeps sepa debtor name snapshot when member billing name changes later" do
    org(
      features: Current.org.features | [ :sepa ],
      country_code: "DE",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: "123",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)

    member.update!(
      different_billing_info: true,
      billing_name: "Changed Corp",
      billing_street: "Changed Street 1",
      billing_city: "Changed City",
      billing_zip: "1111")

    assert_equal "John Doe", invoice.reload.sepa_debtor_name
  end

  test "falls back to current billing info when sepa debtor snapshot is missing" do
    org(
      features: Current.org.features | [ :sepa ],
      country_code: "DE",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: "123",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)
    invoice.update_columns(sepa_debtor_name: nil)

    member.update!(
      different_billing_info: true,
      billing_name: "Fallback Corp",
      billing_street: "Fallback Street 1",
      billing_city: "Fallback City",
      billing_zip: "2222")

    assert_equal "Fallback Corp", invoice.reload.sepa_debtor_name
  end

  test "upload_sepa_direct_debit_order does nothing if order_id already present" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)
    invoice.update!(sepa_direct_debit_order_id: "N001")

    assert_no_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_equal "N001", invoice.sepa_direct_debit_order_id
    assert_nil invoice.sepa_direct_debit_order_uploaded_at
  end

  test "upload_sepa_direct_debit_order does nothing if not sepa" do
    invoice = create_annual_fee_invoice

    assert_no_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_nil invoice.sepa_direct_debit_order_id
    assert_nil invoice.sepa_direct_debit_order_uploaded_at
  end

  test "upload_sepa_direct_debit_order does nothing if no bank_connection" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)

    assert_no_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_nil invoice.sepa_direct_debit_order_id
    assert_nil invoice.sepa_direct_debit_order_uploaded_at
  end

  require "minitest/mock"
  test "upload_sepa_direct_debit_order uploads and updates invoice" do
    german_org(
      sepa_creditor_identifier: "DE98ZZZ09999999999",
      bank_connection_type: "mock",
      bank_credentials: { password: "secret" })
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)
    invoice.touch(:sent_at)

    assert_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_equal "N042", invoice.sepa_direct_debit_order_id
    assert invoice.sepa_direct_debit_order_uploaded_at?
  end
end
