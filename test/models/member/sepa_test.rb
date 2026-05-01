# frozen_string_literal: true

require "test_helper"

class Member::SEPATest < ActiveSupport::TestCase
  def create_sepa_member
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: member.id.to_s,
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload
    member
  end

  test "sepa? returns false when not configured" do
    member = build_member(name: "John Doe")
    assert_not member.sepa?
  end

  test "sepa? returns true when fully configured" do
    member = create_sepa_member

    assert member.sepa?
  end

  test "sepa? returns false when disabled" do
    member = create_sepa_member

    member.disable_sepa!

    assert_not member.reload.sepa?
    assert member.sepa_disabled?
  end

  test "sepa scopes treat disabled members as not sepa" do
    active_member = create_sepa_member
    disabled_member = create_sepa_member
    disabled_member.disable_sepa!

    assert_includes Member.sepa, active_member
    assert_not_includes Member.sepa, disabled_member
    assert_includes Member.not_sepa, disabled_member
  end

  test "disable_sepa! keeps latest mandate history" do
    member = create_sepa_member
    mandate = member.current_sepa_mandate

    member.disable_sepa!

    member.reload
    assert_not member.sepa?
    assert_equal mandate.id, member.current_sepa_mandate.id
  end

  test "admin nested attributes create a new mandate" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "42",
      signed_on: Date.current,
      source: "admin")
    member.reload

    assert_difference("SEPAMandate.count", 1) do
      member.update!(sepa_mandates_attributes: [ { iban: "DE89370400440532013000" } ])
    end

    mandate = member.sepa_mandates.recent_first.first
    assert_equal "DE89370400440532013000", mandate.iban
    assert_equal "admin", mandate.source
    assert_nil mandate.ip
    assert_nil mandate.user_agent
    assert member.reload.sepa?
  end

  test "admin blank iban disables sepa without creating a new mandate" do
    member = create_sepa_member
    current_mandate = member.current_sepa_mandate

    travel_to "2024-06-15" do
      assert_no_difference("SEPAMandate.count") do
        member.update!(sepa_mandates_attributes: [ { iban: "" } ])
      end

      member.reload
      assert_not member.sepa?
      assert member.sepa_disabled?
      assert_equal Date.parse("2024-06-15"), member.sepa_disabled_at.to_date
      assert_equal current_mandate.id, member.current_sepa_mandate.id
    end
  end

  test "admin nested attributes ignore unchanged formatted mandate values" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(country_code: "DE")
    current_mandate = member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "42",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload

    assert_no_difference("SEPAMandate.count") do
      member.update!(sepa_mandates_attributes: [ {
        iban: current_mandate.iban_formatted,
        umr: current_mandate.umr,
        signed_on: current_mandate.signed_on.to_s
      } ])
    end

    assert_equal current_mandate.id, member.reload.current_sepa_mandate.id
  end

  test "admin nested attributes re-enable an unchanged disabled mandate" do
    member = create_sepa_member
    current_mandate = member.current_sepa_mandate
    member.disable_sepa!
    member.reload

    assert_no_difference("SEPAMandate.count") do
      member.update!(sepa_mandates_attributes: [ {
        iban: current_mandate.iban_formatted,
        umr: current_mandate.umr,
        signed_on: current_mandate.signed_on.to_s
      } ])
    end

    assert member.reload.sepa?
    assert_nil member.sepa_disabled_at
    assert_equal current_mandate.id, member.current_sepa_mandate.id
  end
end
