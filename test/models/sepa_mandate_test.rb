# frozen_string_literal: true

require "test_helper"

class SEPAMandateTest < ActiveSupport::TestCase
  def valid_attributes(attributes = {})
    {
      member: members(:john),
      iban: "DE21500500009876543210",
      umr: "42",
      signed_on: Date.current,
      sepa_mandate_accepted: "1",
      source: "self-service"
    }.merge(attributes)
  end

  test "valid with all required fields" do
    mandate = SEPAMandate.new(valid_attributes)
    assert mandate.valid?
  end

  test "requires iban" do
    mandate = SEPAMandate.new(valid_attributes(iban: nil))
    assert_not mandate.valid?
    assert_includes mandate.errors[:iban], "can't be blank"
  end

  # umr, signed_on, and source all have defaults applied by set_defaults
  # before_validation. The meaningful constraint tests are the set_defaults
  # and inclusion tests below.


  test "source must be in allowed list" do
    mandate = SEPAMandate.new(valid_attributes(source: "bogus"))
    assert_not mandate.valid?
    assert_includes mandate.errors[:source], "is not included in the list"
  end

  test "accepts known sources" do
    %w[self-service admin admin-legacy].each do |source|
      mandate = SEPAMandate.new(valid_attributes(source: source))
      assert mandate.valid?, "expected #{source} to be valid"
    end
  end

  test "self-service mandates require explicit consent" do
    mandate = SEPAMandate.new(valid_attributes(sepa_mandate_accepted: nil))

    assert_not mandate.valid?
    assert_includes mandate.errors[:sepa_mandate_accepted], "must be accepted"
  end

  test "session is automatically set from Current.session on create" do
    session = sessions(:john)
    Current.session = session

    mandate = SEPAMandate.create!(valid_attributes)

    assert_equal session, mandate.session
    assert_equal session.owner, mandate.actor
  end

  test "actor falls back to System when no session" do
    mandate = SEPAMandate.create!(valid_attributes)

    assert_nil mandate.session
    assert_equal System.instance, mandate.actor
  end

  test "masked_iban hides middle digits" do
    mandate = SEPAMandate.new(valid_attributes(iban: "DE21500500009876543210"))

    assert_equal "DE21 •••• •••• 3210", mandate.masked_iban
  end

  test "masked_iban returns nil for nil iban" do
    mandate = SEPAMandate.new(valid_attributes)
    mandate.iban = nil

    assert_nil mandate.masked_iban
  end

  test "recent_first orders by created_at descending" do
    member = members(:john)
    old = SEPAMandate.create!(valid_attributes(member: member, created_at: 2.days.ago))
    new_one = SEPAMandate.create!(valid_attributes(member: member, created_at: 1.day.ago))

    assert_equal [ new_one, old ], member.sepa_mandates.recent_first.to_a
  end

  test "set_defaults fills umr from existing mandate, then member id" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    first = SEPAMandate.create!(valid_attributes(member: member, umr: nil))

    assert_equal member.id.to_s, first.umr

    second = SEPAMandate.create!(valid_attributes(member: member, umr: nil, created_at: 1.day.from_now))
    assert_equal first.umr, second.umr
  end

  test "set_defaults fills signed_on with today" do
    travel_to "2024-06-15"
    mandate = SEPAMandate.create!(valid_attributes(signed_on: nil))
    assert_equal Date.parse("2024-06-15"), mandate.signed_on
  end



  test "prevents updating attributes on a persisted mandate" do
    mandate = SEPAMandate.create!(valid_attributes)

    assert_raises(ActiveRecord::ReadOnlyRecord) { mandate.update!(iban: "DE89370400440532013000") }
  end

  test "create fails validation when pdf generation fails" do
    mandate = SEPAMandate.new(valid_attributes)
    mandate.define_singleton_method(:generate_pdf!) { false }

    assert_not mandate.save
    assert_includes mandate.errors[:base],
      I18n.t("errors.attributes.base.pdf_generation_failed")
  end

  test "create re-enables disabled member" do
    member = create_member(country_code: "DE")
    SEPAMandate.create!(
      valid_attributes(
        member: member,
        source: "admin",
        sepa_mandate_accepted: nil))
    member.disable_sepa!
    assert member.reload.sepa_disabled?

    SEPAMandate.create!(
      valid_attributes(
        member: member,
        iban: "DE89370400440532013000",
        source: "admin",
        sepa_mandate_accepted: nil))

    assert_not member.reload.sepa_disabled?
    assert member.sepa?
  end

  test "generate_pdf! attaches a mandate PDF rendered in the member's language" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(
      language: "de",
      country_code: "DE",
      street: "Hauptstraße 1",
      zip: "10115",
      city: "Berlin")
    enable_sepa_mandate_pdf

    mandate = SEPAMandate.create!(
      member: member,
      iban: "DE21500500009876543210",
      umr: member.id.to_s,
      signed_on: Date.current,
      ip: "127.0.0.1",
      user_agent: "Test Browser",
      source: "self-service",
      sepa_mandate_accepted: "1")

    mandate.generate_pdf!

    assert mandate.pdf.attached?
    assert_equal "application/pdf", mandate.pdf.blob.content_type
    assert mandate.pdf.blob.byte_size.positive?
  ensure
    skip_sepa_mandate_pdf
  end
end
