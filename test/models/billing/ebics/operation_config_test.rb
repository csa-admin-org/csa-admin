# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::OperationConfigTest < ActiveSupport::TestCase
  test "defaults Swiss payment downloads to legacy Z54" do
    operation = Billing::EBICS::OperationConfig.new(country_code: "CH").payment_download

    assert operation.order_type?
    assert_equal "Z54", operation.order_type
    assert_equal :Z54, operation.method_name
  end

  test "defaults non-Swiss payment downloads to legacy C53" do
    operation = Billing::EBICS::OperationConfig.new(country_code: "DE").payment_download

    assert operation.order_type?
    assert_equal "C53", operation.order_type
    assert_equal :C53, operation.method_name
  end

  test "defaults direct debit uploads to legacy CDD" do
    config = Billing::EBICS::OperationConfig.new(country_code: "CH")
    operation = config.sepa_direct_debit_upload

    assert operation.order_type?
    assert_equal "CDD", operation.order_type
    assert_equal :CDD, operation.method_name
    assert_equal Billing::SEPADirectDebit::SCHEMA, config.sepa_direct_debit_upload_schema
  end

  test "uses explicit direct debit upload schema from settings" do
    config = Billing::EBICS::OperationConfig.new({
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "order_type",
          "order_type" => "CDD",
          "schema" => "pain.008.001.08"
        }
      }
    })

    assert_equal "CDD", config.sepa_direct_debit_upload.order_type
    assert_equal "pain.008.001.08", config.sepa_direct_debit_upload_schema
  end

  test "derives direct debit upload schema from BTF message version" do
    config = Billing::EBICS::OperationConfig.new({
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "btf" => {
            "order_type" => "BTU",
            "service_name" => "SDD",
            "service_option" => "COR",
            "message_name" => "pain.008",
            "version" => "08"
          }
        }
      }
    })

    assert_equal "BTU", config.sepa_direct_debit_upload.order_type
    assert_equal "pain.008.001.08", config.sepa_direct_debit_upload_schema
  end

  test "uses configured legacy order types" do
    config = Billing::EBICS::OperationConfig.new({
      "downloads" => {
        "payments" => {
          "mode" => "order_type",
          "order_type" => "C54"
        }
      }
    }, country_code: "CH")

    assert_equal "C54", config.payment_download.order_type
  end

  test "normalizes direct BTF operation attributes" do
    operation = Billing::EBICS::Operation.btf(order_type: "BTD", service_name: "REP")

    assert operation.btf?
    assert_equal "BTD", operation.order_type
    assert_equal "REP", operation.btf.fetch("service_name")
  end

  test "keeps BTF operation attributes behind an explicit operation object" do
    config = Billing::EBICS::OperationConfig.new({
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => {
            "order_type" => "BTD",
            "service_name" => "REP",
            "scope" => "CH",
            "container" => "ZIP",
            "message_name" => "camt.054",
            "version" => "04"
          }
        }
      }
    }, country_code: "CH")

    operation = config.payment_download

    assert operation.btf?
    assert_equal "BTD", operation.order_type
    assert_equal "REP", operation.btf.fetch("service_name")
    assert_equal "camt.054", operation.btf.fetch("message_name")
  end
end
