# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::Btf::PresetsTest < ActiveSupport::TestCase
  test "builds Swiss CAMT.054 v04 payment download preset" do
    assert_equal({
      "order_type" => "BTD",
      "service_name" => "REP",
      "scope" => "CH",
      "container" => "ZIP",
      "message_name" => "camt.054",
      "version" => "04"
    }, Billing::EBICS::Btf::Presets.swiss_camt054)
  end

  test "builds optional Swiss CAMT.054 v08 payment download preset" do
    preset = Billing::EBICS::Btf::Presets.swiss_camt054(version: "08")

    assert_equal "BTD", preset.fetch("order_type")
    assert_equal "REP", preset.fetch("service_name")
    assert_equal "CH", preset.fetch("scope")
    assert_equal "ZIP", preset.fetch("container")
    assert_equal "camt.054", preset.fetch("message_name")
    assert_equal "08", preset.fetch("version")
  end

  test "builds German CAMT.053 v08 payment download preset" do
    assert_equal({
      "order_type" => "BTD",
      "service_name" => "EOP",
      "scope" => "DE",
      "container" => "ZIP",
      "message_name" => "camt.053",
      "version" => "08"
    }, Billing::EBICS::Btf::Presets.german_camt053)
  end

  test "resolves payment download preset by country" do
    assert_equal "camt.054", Billing::EBICS::Btf::Presets.payment_download(country_code: "CH").fetch("message_name")
    assert_equal "camt.053", Billing::EBICS::Btf::Presets.payment_download(country_code: "DE").fetch("message_name")
  end

  test "fails clearly when no country preset exists" do
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS::Btf::Presets.payment_download(country_code: "FR")
    end

    assert_includes error.message, "No EBICS BTF payment download preset"
  end
end
