# frozen_string_literal: true

require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "validate only one instance" do
    org = Organization.new(name: "Foo")

    assert_not org.valid?
    assert_includes org.errors[:base], "Only one organization is allowed"
  end

  test "validate url" do
    travel_to Time.zone.now
    assert_equal "acme.test", Tenant.domain

    Current.org.url = "https://www.orga.test"
    assert_not Current.org.valid?

    Current.org.url = "http://www.acme.test"
    assert Current.org.valid?

    Current.org.url = "https://www.acme.test"
    assert Current.org.valid?
  end

  test "validates email_default_from format" do
    travel_to Time.zone.now
    assert_equal "acme.test", Tenant.domain

    Current.org.email_default_from = "info@acme.test"
    assert Current.org.valid?

    Current.org.email_default_from = "contact@acme.test"
    assert Current.org.valid?

    Current.org.email_default_from = "info@orga.test"
    assert_not Current.org.valid?

    Current.org.email_default_from = "acme.test"
    assert_not Current.org.valid?
  end

  test "validates that activity_price cannot be 0" do
    org = Organization.new(activity_price: nil)
    assert_not org.valid?
  end

  test "validates activity_participations_demanded_logic liquid syntax" do
    org = Organization.new(activity_participations_demanded_logic: <<~LIQUID)
      {% if member.salary_basket %}
    LIQUID

    assert_not org.valid?
    assert_includes org.errors[:activity_participations_demanded_logic], "Liquid syntax error: 'if' tag was never closed"
  end

  test "validates basket_price_extra_dynamic_pricing liquid syntax" do
    org = Organization.new(basket_price_extra_dynamic_pricing: <<~LIQUID)
      {% if extra %}
    LIQUID

    assert_not org.valid?
    assert_includes org.errors[:basket_price_extra_dynamic_pricing], "Liquid syntax error: 'if' tag was never closed"
  end

  test "validate share related attribute presence" do
    org = Current.org

    org.assign_attributes(share_price: 50, shares_number: nil)
    assert_not org.valid?

    org.assign_attributes(share_price: nil, shares_number: 1)
    assert_not org.valid?

    org.assign_attributes(share_price: 50, shares_number: 1)
    assert org.valid?
  end

  test "validates IBAN format with CH QR IBAN" do
    org = Current.org

    org.iban = "CH3230114A012B456789z"
    assert org.valid?
    assert_equal "CH3230114A012B456789Z", org.iban
    assert_equal "CH32 3011 4A01 2B45 6789 Z", org.iban_formatted

    org.iban = "CH3231114A012B456789z"
    assert org.valid?

    org.iban = "CH3232004A012B456789z"
    assert_not org.valid?

    org.iban = "CH 33 30767 000K 5510"
    assert_not org.valid?

    org.iban = ""
    assert org.valid?
  end

  test "validates IBAN format with FR IBAN" do
    org = Current.org
    org.country_code = "FR"

    org.iban = "FR7630006000011234567890189"
    assert org.valid?
    assert_equal "FR7630006000011234567890189", org.iban
    assert_equal "FR76 3000 6000 0112 3456 7890 189", org.iban_formatted

    org.iban = "FR763000600001123456789018"
    assert_not org.valid?

    org.iban = "DE89370400440532013000"
    assert_not org.valid?
  end

  test "validates IBAN format with DE IBAN" do
    org = Current.org
    org.country_code = "DE"

    org.iban = "DE89370400440532013000"
    assert org.valid?
    assert_equal "DE89370400440532013000", org.iban
    assert_equal "DE89 3704 0044 0532 0130 00", org.iban_formatted

    org.iban = "DE8937040044053201300"
    assert_not org.valid?

    org.iban = "FR7630006000011234567890189"
    assert_not org.valid?
  end

  test "billing_year_divisions= keeps only allowed divisions" do
    org = Organization.new(billing_year_divisions: [ "", "1", "6", "12" ])
    assert_equal [ 1, 12 ], org.billing_year_divisions
  end

  test "apply_annual_fee_change" do
    org(annual_fee: 30)

    members(:john).update_column(:annual_fee, 20)
    members(:martha).update_column(:annual_fee, 30)

    assert_difference -> { Member.where(annual_fee: 40).count }, 5 do
      Current.org.update!(annual_fee: 40)
    end

    assert_equal [ nil, 20, 40 ], Member.order(:annual_fee).pluck(:annual_fee).uniq
  end

  test "#basket_shift_enabled?" do
    org(absences_billed: true)

    org(basket_shifts_annually: 0)
    assert_not Current.org.basket_shift_enabled?

    org(basket_shifts_annually: 1)
    assert Current.org.basket_shift_enabled?

    org(basket_shifts_annually: nil)
    assert Current.org.basket_shift_enabled?

    org(absences_billed: false)
    assert_not Current.org.absences_billed?
  end
end
