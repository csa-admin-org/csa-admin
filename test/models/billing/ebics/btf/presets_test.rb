# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::Btf::PresetsTest < ActiveSupport::TestCase
  test "builds CAMT.054 BTD preset from explicit BTF attributes" do
    assert_equal({
      "order_type" => "BTD",
      "service_name" => "REP",
      "scope" => "CH",
      "container" => "ZIP",
      "message_name" => "camt.054",
      "version" => "04"
    }, Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04"))
  end

  test "builds optional CAMT.054 v08 preset" do
    preset = Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "08")

    assert_equal "BTD", preset.fetch("order_type")
    assert_equal "REP", preset.fetch("service_name")
    assert_equal "CH", preset.fetch("scope")
    assert_equal "ZIP", preset.fetch("container")
    assert_equal "camt.054", preset.fetch("message_name")
    assert_equal "08", preset.fetch("version")
  end

  test "builds CAMT.053 BTD preset without a message version" do
    assert_equal({
      "order_type" => "BTD",
      "service_name" => "EOP",
      "scope" => "DE",
      "container" => "ZIP",
      "message_name" => "camt.053"
    }, Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE"))
  end

  test "builds CAMT.053 BTD preset with an explicit message version" do
    assert_equal "08", Billing::EBICS::Btf::Presets
      .camt053(service_name: "EOP", scope: "DE", version: "08")
      .fetch("version")
  end

  test "resolves payment download preset by country" do
    assert_equal "camt.054", Billing::EBICS::Btf::Presets.payment_download(country_code: "CH").fetch("message_name")
    assert_equal "04", Billing::EBICS::Btf::Presets.payment_download(country_code: "CH").fetch("version")
    assert_equal "camt.053", Billing::EBICS::Btf::Presets.payment_download(country_code: "DE").fetch("message_name")
    assert_not Billing::EBICS::Btf::Presets.payment_download(country_code: "DE").key?("version")
  end

  test "builds non-container SEPA direct debit BTU preset" do
    assert_equal({
      "order_type" => "BTU",
      "service_name" => "SDD",
      "service_option" => "COR",
      "message_name" => "pain.008",
      "version" => "08",
      "signature_flag" => true
    }, Billing::EBICS::Btf::Presets.sepa_direct_debit_upload)
  end

  test "builds XML-container SEPA direct debit BTU preset" do
    assert_equal({
      "order_type" => "BTU",
      "service_name" => "SDD",
      "scope" => "DE",
      "service_option" => "COR",
      "container" => "XML",
      "message_name" => "pain.008",
      "version" => "08",
      "signature_flag" => true
    }, Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(scope: "DE", container: "XML"))
  end

  test "builds SEPA direct debit status report BTD preset" do
    assert_equal({
      "order_type" => "BTD",
      "service_name" => "REP",
      "scope" => "DE",
      "service_option" => "SDD",
      "container" => "ZIP",
      "message_name" => "pain.002"
    }, Billing::EBICS::Btf::Presets.sepa_direct_debit_status_report)
  end

  test "fails clearly when no country preset exists" do
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS::Btf::Presets.payment_download(country_code: "FR")
    end

    assert_includes error.message, "No EBICS BTF payment download preset"
  end
end
