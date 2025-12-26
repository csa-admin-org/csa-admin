# frozen_string_literal: true

require "test_helper"

class Member::BillingTest < ActiveSupport::TestCase
  test "billable? support member" do
    member = members(:martha)
    assert member.billable?
  end

  test "billable? inactive member" do
    member = members(:mary)
    assert_not member.billable?
  end

  test "billable? past membership" do
    travel_to "2026-01-01"
    member = members(:john)
    assert_not member.billable?
  end

  test "billable? ongoing membership" do
    travel_to "2024-01-01"
    member = members(:john)
    assert member.billable?
  end

  test "billable? future membership" do
    travel_to "2025-01-01"
    member = members(:john)
    assert member.billable?
  end

  test "billing_email strips whitespace" do
    member = members(:john)
    member.billing_email = "  billing@example.com  "
    assert_equal "billing@example.com", member.billing_email
  end

  test "billing_emails returns billing_email when set" do
    member = members(:john)
    member.update!(billing_email: "billing@example.com")

    assert_equal [ "billing@example.com" ], member.billing_emails
  end

  test "billing_emails returns active_emails when no billing_email" do
    member = members(:john)
    member.update!(billing_email: nil)

    assert_equal member.active_emails, member.billing_emails
  end

  test "billing_emails returns empty when billing_email is suppressed" do
    member = members(:john)
    member.update!(billing_email: "suppressed@example.com")
    suppress_email("suppressed@example.com")

    assert_empty member.billing_emails
  end

  test "billing_emails? returns true when billing emails exist" do
    member = members(:john)
    assert member.billing_emails?
  end

  test "billing_emails? returns false when no billing emails" do
    member = members(:john)
    member.update!(emails: "", billing_email: "")

    assert_not member.billing_emails?
  end

  test "use different billing info" do
    member = members(:john)
    assert_not member.different_billing_info

    member.different_billing_info = true
    assert_not member.valid?
    assert_includes member.errors[:billing_name], "can't be blank"
    assert_includes member.errors[:billing_street], "can't be blank"
    assert_includes member.errors[:billing_city], "can't be blank"
    assert_includes member.errors[:billing_zip], "can't be blank"

    member.update!(
      different_billing_info: true,
      billing_name: "Acme Doe",
      billing_street: "Acme Street 42",
      billing_city: "Acme City",
      billing_zip: "1234")
    assert member.different_billing_info
    assert_equal "Acme Doe", member.billing_info(:name)
    assert_equal "Acme Street 42", member.billing_info(:street)
    assert_equal "Acme City", member.billing_info(:city)
    assert_equal "1234", member.billing_info(:zip)

    member.update!(different_billing_info: "0")
    assert_not member.different_billing_info
    assert_nil member.billing_name
    assert_nil member.billing_street
    assert_nil member.billing_city
    assert_nil member.billing_zip
  end

  test "billing_info returns billing value when set" do
    member = members(:john)
    member.update!(
      different_billing_info: true,
      billing_name: "Billing Name",
      billing_street: "Billing Street",
      billing_city: "Billing City",
      billing_zip: "9999")

    assert_equal "Billing Name", member.billing_info(:name)
    assert_equal "Billing Street", member.billing_info(:street)
    assert_equal "Billing City", member.billing_info(:city)
    assert_equal "9999", member.billing_info(:zip)
  end

  test "billing_info returns regular value when billing not set" do
    member = members(:john)

    assert_equal member.name, member.billing_info(:name)
    assert_equal member.street, member.billing_info(:street)
    assert_equal member.city, member.billing_info(:city)
    assert_equal member.zip, member.billing_info(:zip)
  end

  test "invoices_amount returns sum of non-canceled invoices" do
    member = members(:martha)
    assert_equal member.invoices.not_canceled.sum(:amount), member.invoices_amount
  end

  test "payments_amount returns sum of non-ignored payments" do
    member = members(:martha)
    assert_equal member.payments.not_ignored.sum(:amount), member.payments_amount
  end

  test "balance_amount calculates difference between payments and invoices" do
    member = members(:martha)
    expected = member.payments_amount - member.invoices_amount
    assert_equal expected, member.balance_amount
  end

  test "credit_amount returns positive balance or zero" do
    member = members(:martha)

    if member.balance_amount.positive?
      assert_equal member.balance_amount, member.credit_amount
    else
      assert_equal 0, member.credit_amount
    end
  end

  test "validates mandate signed on presence with SEPA" do
    org(country_code: "DE", iban: "DE89370400440532013000")
    member = build_member(sepa_mandate_id: "123", sepa_mandate_signed_on: nil)
    assert_not member.valid?
    assert_includes member.errors[:sepa_mandate_signed_on], "can't be blank"
  end

  test "validates IBAN with SEPA" do
    org(country_code: "DE", iban: "DE89370400440532013000")
    member = build_member(
      country_code: "DE",
      sepa_mandate_id: "123",
      sepa_mandate_signed_on: 1.day.ago,
      iban: nil)
    assert_not member.valid?
    member.update(iban: "CH9300762011623852957")
    assert_not member.valid?
    member.update(iban: "DE89370400440532013333")
    assert_not member.valid? # check digit is invalid
    member.update(iban: "DE21500500009876543210")
    assert member.valid?
  end

  test "sepa? returns false when not configured" do
    member = build_member(name: "John Doe")
    assert_not member.sepa?
  end

  test "sepa? returns true when fully configured" do
    member = build_member(
      name: "John Doe",
      iban: "DE89370400440532013000",
      sepa_mandate_id: "123",
      sepa_mandate_signed_on: "2024-01-01")
    assert member.sepa?
  end

  test "sepa_metadata returns empty hash when not sepa" do
    member = build_member(name: "John Doe")
    assert_empty member.sepa_metadata
  end

  test "sepa_metadata returns full hash when sepa configured" do
    member = build_member(
      name: "John Doe",
      iban: "DE89370400440532013000",
      sepa_mandate_id: "123",
      sepa_mandate_signed_on: "2024-01-01")

    assert_equal({
      name: "John Doe",
      iban: "DE89370400440532013000",
      mandate_id: "123",
      mandate_signed_on: Date.parse("2024-01-01")
    }, member.sepa_metadata)
  end
end
