# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::OperationConfigTest < ActiveSupport::TestCase
  test "requires explicit BTF payment download settings" do
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS::OperationConfig.new.payment_download
    end

    assert_equal "Active EBICS payment_download must use explicit BTF settings", error.message
  end

  test "rejects legacy payment download order types" do
    config = Billing::EBICS::OperationConfig.new({
      "downloads" => {
        "payments" => {
          "mode" => "order_type",
          "order_type" => "C54"
        }
      }
    })

    error = assert_raises(Billing::EBICS::UnsupportedOperation) { config.payment_download }
    assert_equal "Active EBICS payment_download must use explicit BTF settings", error.message
  end

  test "rejects upload BTF tuple for payment downloads" do
    config = Billing::EBICS::OperationConfig.new({
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload
        }
      }
    })

    error = assert_raises(Billing::EBICS::UnsupportedOperation) { config.payment_download }
    assert_equal "Active EBICS payment_download must use BTD BTF settings", error.message
  end

  test "requires explicit BTF direct debit upload settings" do
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS::OperationConfig.new.sepa_direct_debit_upload
    end

    assert_equal "Active EBICS sepa_direct_debit_upload must use explicit BTF settings", error.message
  end

  test "rejects legacy direct debit upload order types" do
    config = Billing::EBICS::OperationConfig.new({
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "order_type",
          "order_type" => "CDD"
        }
      }
    })

    error = assert_raises(Billing::EBICS::UnsupportedOperation) { config.sepa_direct_debit_upload }
    assert_equal "Active EBICS sepa_direct_debit_upload must use explicit BTF settings", error.message
  end

  test "rejects download BTF tuple for direct debit uploads" do
    config = Billing::EBICS::OperationConfig.new({
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
    })

    error = assert_raises(Billing::EBICS::UnsupportedOperation) { config.sepa_direct_debit_upload }
    assert_equal "Active EBICS sepa_direct_debit_upload must use BTU BTF settings", error.message
  end

  test "rejects XML-container settings for raw direct debit uploads" do
    config = Billing::EBICS::OperationConfig.new({
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(
            scope: "DE",
            container: "XML")
        }
      }
    })

    error = assert_raises(Billing::EBICS::UnsupportedOperation) { config.sepa_direct_debit_upload }
    assert_equal "EBICS BTF SEPA direct debit uploads require a non-container service", error.message
  end

  test "requires direct debit upload schema from explicit schema or BTF version" do
    config = Billing::EBICS::OperationConfig.new({
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(version: nil)
        }
      }
    })

    error = assert_raises(Billing::EBICS::UnsupportedOperation) { config.sepa_direct_debit_upload_schema }
    assert_equal "Missing EBICS BTF SEPA direct debit upload schema", error.message
  end

  test "uses explicit direct debit upload schema from settings" do
    config = Billing::EBICS::OperationConfig.new({
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "schema" => "pain.008.001.08",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(version: nil)
        }
      }
    })

    assert_equal "BTU", config.sepa_direct_debit_upload.order_type
    assert_equal "pain.008.001.08", config.sepa_direct_debit_upload_schema
  end

  test "derives direct debit upload schema from BTF message version" do
    config = Billing::EBICS::OperationConfig.new({
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(version: "08")
        }
      }
    })

    assert_equal "BTU", config.sepa_direct_debit_upload.order_type
    assert_equal "pain.008.001.08", config.sepa_direct_debit_upload_schema
  end

  test "normalizes direct BTF operation attributes" do
    operation = Billing::EBICS::Operation.btf(order_type: "BTD", service_name: "REP")

    assert_equal "BTD", operation.order_type
    assert_equal "REP", operation.btf.fetch("service_name")
  end

  test "keeps BTF operation attributes behind an explicit operation object" do
    config = Billing::EBICS::OperationConfig.new({
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
    })

    operation = config.payment_download

    assert_equal "BTD", operation.order_type
    assert_equal "REP", operation.btf.fetch("service_name")
    assert_equal "camt.054", operation.btf.fetch("message_name")
  end
end
