# frozen_string_literal: true

require "test_helper"
require_relative "../../db/migrate/20260710144000_sanitize_bank_connection_capabilities"

class SanitizeBankConnectionCapabilitiesTest < ActiveSupport::TestCase
  test "removes legacy provider text from persisted capabilities" do
    BankConnection.delete_all
    provider_text = "secret member@example.test <Document>payment data</Document>"
    connection = BankConnection.create!(
      provider: "ebics",
      active: false,
      state: "disabled",
      capabilities: {
        "h005" => {
          "admin_orders" => {
            "HTD" => {
              "message" => provider_text,
              "report_text" => provider_text
            }
          }
        }
      })

    SanitizeBankConnectionCapabilities.new.migrate(:up)

    capabilities = connection.reload.capabilities
    assert_equal provider_text.bytesize, capabilities.dig("h005", "admin_orders", "HTD", "message_length")
    assert_equal Digest::SHA256.hexdigest(provider_text), capabilities.dig("h005", "admin_orders", "HTD", "report_text_sha256")
    assert_not_includes capabilities.to_json, provider_text
  end
end
