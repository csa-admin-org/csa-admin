# frozen_string_literal: true

require "test_helper"

class Invoice::SEPATest < ActiveSupport::TestCase
  test "persisted sepa_metadata on invoice creation" do
    org(
      country_code: "DE",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE",
      iban: "DE89370400440532013000",
      sepa_mandate_id: "123",
      sepa_mandate_signed_on: Date.parse("2024-01-01"))

    invoice = create_annual_fee_invoice(member: member)
    assert_equal({
      "name" => "John Doe",
      "iban" => "DE89370400440532013000",
      "mandate_id" => "123",
      "mandate_signed_on" => "2024-01-01"
    }, invoice.sepa_metadata)
    assert invoice.sepa?
  end

  test "persisted sepa_metadata uses billing_info name when different billing info is set" do
    org(
      country_code: "DE",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE",
      iban: "DE89370400440532013000",
      sepa_mandate_id: "123",
      sepa_mandate_signed_on: Date.parse("2024-01-01"))
    member.update!(
      different_billing_info: true,
      billing_name: "Acme Corp",
      billing_street: "Billing Street 1",
      billing_city: "Billing City",
      billing_zip: "9999")

    invoice = create_annual_fee_invoice(member: member)
    assert_equal({
      "name" => "Acme Corp",
      "iban" => "DE89370400440532013000",
      "mandate_id" => "123",
      "mandate_signed_on" => "2024-01-01"
    }, invoice.sepa_metadata)
    assert invoice.sepa?
  end

  test "upload_sepa_direct_debit_order does nothing if order_id already present" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(
      language: "de",
      iban: "DE21500500009876543210",
      sepa_mandate_id: "123456",
      sepa_mandate_signed_on: "2023-12-24")
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
    member.update!(
      language: "de",
      iban: "DE21500500009876543210",
      sepa_mandate_id: "123456",
      sepa_mandate_signed_on: "2023-12-24")
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
    member.update!(
      language: "de",
      iban: "DE21500500009876543210",
      sepa_mandate_id: "123456",
      sepa_mandate_signed_on: "2023-12-24")
    invoice = create_annual_fee_invoice(member: member)
    invoice.touch(:sent_at)

    assert_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_equal "N042", invoice.sepa_direct_debit_order_id
    assert invoice.sepa_direct_debit_order_uploaded_at?
  end
end
