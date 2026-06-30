# frozen_string_literal: true

require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "validate only one instance" do
    org = Organization.new(name: "Foo")

    assert_not org.valid?
    assert_includes org.errors[:base], "Only one organization is allowed"
  end

  test "validates email_default_from format" do
    travel_to Time.zone.now
    assert_equal "acme.test", Current.org.domain

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

  test "validates maps style" do
    assert_equal %w[positron bright liberty dark fiord], Organization.map_styles
    assert_equal "positron", Organization.new.maps_style

    Current.org.maps_style = "3d"

    assert_not Current.org.valid?
    assert_includes Current.org.errors[:maps_style], "is not included in the list"
  end

  test "website origins use configured website domain" do
    Current.org.url = "https://www.acme.test/depot-map"

    assert_equal "https://www.acme.test", Current.org.website_origin
    assert_equal "https://*.acme.test", Current.org.website_subdomain_origin
    assert_equal [ "https://www.acme.test", "https://*.acme.test" ], Current.org.website_origins
  end

  test "website origins keep non-standard ports" do
    Current.org.url = "http://www.acme.test:3000/depot-map"

    assert_equal "http://www.acme.test:3000", Current.org.website_origin
    assert_equal "http://*.acme.test:3000", Current.org.website_subdomain_origin
  end

  test "website origins keep ports that are only default for another scheme" do
    Current.org.url = "http://www.acme.test:443/depot-map"

    assert_equal "http://www.acme.test:443", Current.org.website_origin
    assert_equal "http://*.acme.test:443", Current.org.website_subdomain_origin
  end

  test "website origins do not wildcard IP addresses" do
    Current.org.url = "http://127.0.0.1:3000"

    assert_equal "http://127.0.0.1:3000", Current.org.website_origin
    assert_nil Current.org.website_subdomain_origin
    assert_equal [ "http://127.0.0.1:3000" ], Current.org.website_origins
  end

  test "member form depot map is only enabled when maps feature is active" do
    org(features: [], member_form_depot_map: true)
    assert_not Current.org.member_form_depot_map_enabled?

    org(features: [ "maps" ], member_form_depot_map: false)
    assert_not Current.org.member_form_depot_map_enabled?

    org(features: [ "maps" ], member_form_depot_map: true)
    assert Current.org.member_form_depot_map_enabled?
  end

  test "validates annual fee only when feature is enabled" do
    org = Current.org

    org.assign_attributes(features: [ "annual_fee" ], annual_fee: nil)
    assert_not org.valid?
    assert_includes org.errors[:annual_fee], "can't be blank"

    org.assign_attributes(
      features: [],
      annual_fee: 30,
      annual_fee_member_form: true,
      annual_fee_support_member_only: true)
    assert org.valid?
  end

  test "validates share related attributes only when feature is enabled" do
    org = Current.org

    org.assign_attributes(features: [ "shares" ], share_price: 50, shares_number: nil)
    assert_not org.valid?
    assert_includes org.errors[:shares_number], "can't be blank"

    org.assign_attributes(features: [ "shares" ], share_price: nil, shares_number: 1)
    assert_not org.valid?
    assert_includes org.errors[:share_price], "can't be blank"

    org.assign_attributes(features: [ "shares" ], share_price: 50, shares_number: 1)
    assert org.valid?

    org.assign_attributes(features: [], share_price: 50, shares_number: nil)
    assert org.valid?
  end

  test "validates VAT settings only when feature is enabled" do
    org = Current.org

    org.assign_attributes(
      features: [ "vat" ],
      vat_number: nil,
      vat_membership_rate: nil,
      vat_activity_rate: nil,
      vat_shop_rate: nil)
    assert_not org.valid?
    assert_includes org.errors[:vat_number], "can't be blank"
    assert_includes org.errors[:vat_membership_rate], "can't be blank"
    assert_empty org.errors[:vat_activity_rate]
    assert_empty org.errors[:vat_shop_rate]

    org.assign_attributes(features: [ "vat" ], vat_number: "CHE-103.987.077")
    assert_not org.valid?
    assert_includes org.errors[:vat_membership_rate], "can't be blank"
    assert_empty org.errors[:vat_activity_rate]
    assert_empty org.errors[:vat_shop_rate]

    org.assign_attributes(
      features: [ "vat" ],
      vat_membership_rate: 2.6,
      vat_activity_rate: nil,
      vat_shop_rate: nil)
    assert org.valid?

    org.assign_attributes(features: [], vat_number: "CHE-103.987.077", vat_membership_rate: nil)
    assert org.valid?
  end

  test "keeps SEPA country support separate from feature configuration" do
    org = Current.org

    org.assign_attributes(
      features: [],
      country_code: "DE",
      iban: "DE89370400440532013000",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    assert org.sepa_country?
    assert_not org.sepa?
    assert_not org.sepa_configured?
    assert org.valid?

    org.assign_attributes(features: [ "sepa" ], country_code: "CH")
    assert_not org.valid?
    assert_includes org.errors[:country_code], "is not included in the list"

    org.assign_attributes(
      features: [ "sepa" ],
      country_code: "DE",
      iban: "DE89370400440532013000",
      sepa_creditor_identifier: nil)
    assert_not org.valid?
    assert_includes org.errors[:sepa_creditor_identifier], "can't be blank"

    org.assign_attributes(features: [ "sepa" ], sepa_creditor_identifier: "DE98ZZZ09999999999")
    assert org.sepa?
    assert org.sepa_configured?
    assert org.valid?
  end

  test "validates member information text for every organization language only when feature is enabled" do
    org = Current.org

    org.assign_attributes(
      features: [ "member_information" ],
      languages: [ "en", "fr" ],
      basket_content_member_title_fr: "Votre contenu de panier")
    assert_not org.valid?
    assert_includes org.errors[:member_information_text_en], "can't be blank"
    assert_includes org.errors[:member_information_text_fr], "can't be blank"

    org.member_information_text_en = "Confidential member text"
    assert_not org.valid?
    assert_empty org.errors[:member_information_text_en]
    assert_includes org.errors[:member_information_text_fr], "can't be blank"

    org.member_information_text_fr = "Infos confidentielles membres"
    assert org.valid?

    org.assign_attributes(features: [])
    org.member_information_text_en = ""
    org.member_information_text_fr = ""
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

  test "validates bidding round basket price percentage settings" do
    org = Current.org

    org.bidding_round_basket_size_price_min_percentage = 20
    org.bidding_round_basket_size_price_max_percentage = 50
    assert org.valid?

    org.bidding_round_basket_size_price_min_percentage = 150
    assert_not org.valid?
    assert_includes org.errors[:bidding_round_basket_size_price_min_percentage], "must be less than or equal to 100"

    org.bidding_round_basket_size_price_min_percentage = 20
    org.bidding_round_basket_size_price_max_percentage = 0
    assert_not org.valid?
    assert_includes org.errors[:bidding_round_basket_size_price_max_percentage], "must be greater than or equal to 1"

    org.bidding_round_basket_size_price_min_percentage = -10
    org.bidding_round_basket_size_price_max_percentage = 50
    assert_not org.valid?
    assert_includes org.errors[:bidding_round_basket_size_price_min_percentage], "must be greater than or equal to 0"
  end

  test "validates open_bidding_round_reminder_sent_after_in_days setting" do
    org = Current.org

    org.open_bidding_round_reminder_sent_after_in_days = 7
    assert org.valid?

    org.open_bidding_round_reminder_sent_after_in_days = nil
    assert org.valid?

    org.open_bidding_round_reminder_sent_after_in_days = 0
    assert_not org.valid?
    assert_includes org.errors[:open_bidding_round_reminder_sent_after_in_days], "must be greater than or equal to 1"

    org.open_bidding_round_reminder_sent_after_in_days = -5
    assert_not org.valid?
    assert_includes org.errors[:open_bidding_round_reminder_sent_after_in_days], "must be greater than or equal to 1"
  end
end
