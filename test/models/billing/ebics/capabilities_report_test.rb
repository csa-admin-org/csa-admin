# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::CapabilitiesReportTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
  end

  test "reports sanitized H005 BTF capabilities from HTD and HAA" do
    org(country_code: "DE")
    connection = BankConnection.create!(
      provider: "ebics",
      name: "MULTIVIA",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: ebics_settings)

    report = Billing::EBICS::CapabilitiesReport.new(
      tenant: "wilderauke",
      connection: connection,
      btf_client: FakeBtfClient.new).to_h

    assert_equal "wilderauke", report.fetch("tenant")
    assert_equal "MULTIVIA", report.dig("active_connection", "name")
    assert_equal BankConnection::FILTERED, report.dig("active_connection", "settings", "downloads", "secret")
    assert_equal "ok", report.dig("h005", "admin_orders", "HTD", "status")
    assert_nil report.dig("h005", "admin_orders", "HTD", "legacy_order_types")
    assert_equal "BTD", report.dig("h005", "htd_btf_downloads", 0, "admin_order_type")
    assert_equal "EOP", report.dig("h005", "htd_btf_downloads", 0, "service", "service_name")
    assert_equal "DE", report.dig("h005", "htd_btf_downloads", 0, "service", "scope")
    assert_equal "ZIP", report.dig("h005", "htd_btf_downloads", 0, "service", "container")
    assert_equal "camt.053", report.dig("h005", "htd_btf_downloads", 0, "service", "message_name")
    assert_nil report.dig("h005", "htd_btf_downloads", 0, "service", "version")
    assert_not_includes report.to_json, "End of Period Statement"
    assert_equal "BTU", report.dig("h005", "htd_btf_uploads", 0, "admin_order_type")
    assert_equal "SDD", report.dig("h005", "htd_btf_uploads", 0, "service", "service_name")
    assert_equal "camt.053", report.dig("h005", "haa_available_downloads", 0, "message_name")
    assert_sanitized report
  end

  test "reports sanitized admin order return details" do
    connection = BankConnection.create!(
      provider: "ebics",
      name: "BCVDEBICS",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: ebics_settings)

    report = Billing::EBICS::CapabilitiesReport.new(
      tenant: "lafermedugoupil",
      connection: connection,
      btf_client: FailingBtfClient.new).to_h

    assert_equal "error", report.dig("h005", "admin_orders", "HTD", "status")
    assert_equal "090003", report.dig("h005", "admin_orders", "HTD", "return_code")
    assert_equal "ebics_response", report.dig("h005", "admin_orders", "HTD", "category")
    assert_not_includes report.to_json, "provider response text"
  end

  private

  def ebics_credentials
    @ebics_credentials ||= synthetic_ebics_credentials(
      secret: "test-capability-secret",
      host_id: "MULTIVIA",
      user_id: "PARTICIPANTID",
      partner_id: "CLIENTID")
  end

  def ebics_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE")
        },
        "secret" => "settings-secret"
      }
    }
  end

  def assert_sanitized(report)
    output = report.to_json

    assert_not_includes output, ebics_credentials.fetch("secret")
    assert_not_includes output, ebics_credentials.fetch("keys")
    assert_not_includes output, "settings-secret"
  end

  class FakeBtfClient
    def admin_order(order_type)
      Billing::EBICS::BtfClient::AdminOrderResult.new(
        order_data: public_send("#{order_type.downcase}_xml"),
        receipt_sent: true)
    end

    def htd_xml
      <<~XML
        <HTDResponseOrderData xmlns="urn:org:ebics:H005">
          <PartnerInfo>
            <AddressInfo/>
            <BankInfo><HostID>MULTIVIA</HostID></BankInfo>
            <OrderInfo>
              <AdminOrderType>BTD</AdminOrderType>
              <Service>
                <ServiceName>EOP</ServiceName>
                <Scope>DE</Scope>
                <Container containerType="ZIP"/>
                <MsgName>camt.053</MsgName>
              </Service>
              <Description>End of Period Statement</Description>
              <NumSigRequired>0</NumSigRequired>
            </OrderInfo>
            <OrderInfo>
              <AdminOrderType>BTU</AdminOrderType>
              <Service>
                <ServiceName>SDD</ServiceName>
                <ServiceOption>COR</ServiceOption>
                <MsgName>pain.008</MsgName>
              </Service>
              <Description>SEPA Direct Debit Core</Description>
            </OrderInfo>
          </PartnerInfo>
          <UserInfo>
            <UserID Status="0">USERID</UserID>
            <Permission>
              <AdminOrderType>BTD</AdminOrderType>
              <Service>
                <ServiceName>EOP</ServiceName>
                <Scope>DE</Scope>
                <Container containerType="ZIP"/>
                <MsgName>camt.053</MsgName>
              </Service>
            </Permission>
          </UserInfo>
        </HTDResponseOrderData>
      XML
    end

    def haa_xml
      <<~XML
        <HAAResponseOrderData xmlns="urn:org:ebics:H005">
          <Service>
            <ServiceName>EOP</ServiceName>
            <Scope>DE</Scope>
            <Container containerType="ZIP"/>
            <MsgName>camt.053</MsgName>
          </Service>
        </HAAResponseOrderData>
      XML
    end
  end

  class FailingBtfClient
    def admin_order(_order_type)
      response_error = Billing::EBICS::BtfClient::ResponseError.new(FailingResponse.new)
      raise Billing::EBICS::ClientError.new(response_error)
    end
  end

  class FailingResponse
    def return_code = "090003"
    def report_text = "provider response text"
  end
end
