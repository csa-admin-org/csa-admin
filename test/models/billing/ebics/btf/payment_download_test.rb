# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::Btf::PaymentDownloadTest < ActiveSupport::TestCase
  test "uses version 08 when that payment download advertises it" do
    assert_equal "08", version_of(effective(swiss_btf("04"), "08"))
    assert_equal "08", version_of(effective(swiss_btf("04"), "04", "08"))
    assert_equal "08", version_of(effective(german_btf, "08", nil))
    assert_equal "08", version_of(effective_from_haa(german_btf, "08"))
    assert_equal "camt.054", effective(swiss_btf("04"), "08").dig("downloads", "payments", "btf", "message_name")
    assert_equal "camt.053", effective(german_btf, "08").dig("downloads", "payments", "btf", "message_name")
  end

  test "keeps the configured version when version 08 is not advertised" do
    assert_equal "04", version_of(effective(swiss_btf("04"), "04"))
    assert_equal "04", version_of(effective(swiss_btf("04"), nil))
    assert_equal "04", version_of(effective(swiss_btf("04")))
    assert_nil version_of(effective(german_btf, "04"))
    assert_nil version_of(effective(german_btf, nil))
    assert_equal "02", version_of(effective(german_btf("02"), "04"))
  end

  test "does not report the download missing when the chosen version is advertised" do
    assert_not connection_for(swiss_btf("04"), "08").ebics_payment_download_missing?
    assert_not connection_for(swiss_btf("04"), "04").ebics_payment_download_missing?
    assert_not connection_for(german_btf, "08").ebics_payment_download_missing?
    assert_not connection_for(german_btf, nil).ebics_payment_download_missing?
    assert_not connection_for(swiss_btf("04")).ebics_payment_download_missing?
  end

  test "reports the download missing when the configured version is absent" do
    assert connection_for(swiss_btf("04"), "09").ebics_payment_download_missing?
    assert connection_for(german_btf, "04").ebics_payment_download_missing?
  end

  private

  def effective(btf, *versions)
    Billing::EBICS::Btf::PaymentDownload.effective_settings(connection_for(btf, *versions))
  end

  def effective_from_haa(btf, version)
    connection = connection_for(btf)
    connection.capabilities = {
      "h005" => { "haa_available_downloads" => [ service_for(btf, version) ] }
    }
    Billing::EBICS::Btf::PaymentDownload.effective_settings(connection)
  end

  def version_of(settings)
    settings.dig("downloads", "payments", "btf", "version")
  end

  def connection_for(btf, *versions)
    BankConnection.new(
      provider: "ebics",
      settings: {
        "downloads" => {
          "payments" => {
            "mode" => "btf",
            "btf" => btf
          }
        }
      },
      capabilities: {
        "h005" => {
          "htd_btf_downloads" => versions.map { |version|
            { "admin_order_type" => "BTD", "service" => service_for(btf, version) }
          }
        }
      })
  end

  def service_for(btf, version)
    service = btf.except("order_type")
    return service.except("version") if version.blank?

    service.merge("version" => version)
  end

  def swiss_btf(version)
    Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: version)
  end

  def german_btf(version = nil)
    Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE", version: version)
  end
end
