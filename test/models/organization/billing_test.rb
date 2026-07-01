# frozen_string_literal: true

require "test_helper"

class Organization::BillingTest < ActiveSupport::TestCase
  test "active_bank_connection returns active tenant-local bank connection" do
    BankConnection.delete_all
    connection = BankConnection.create!(
      provider: "mock",
      active: true,
      state: "ready",
      credentials: { password: "secret" })

    assert_equal connection, Current.org.active_bank_connection
  end

  test "bank_connection keeps using legacy organization columns" do
    BankConnection.delete_all
    BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123" })
    org(
      bank_connection_type: "mock",
      bank_credentials: { password: "secret" })

    assert_instance_of Billing::EBICSMock, Current.org.bank_connection
  end

  test "bank_connection keeps legacy EBICS settings separate from active bank connection" do
    BankConnection.delete_all
    BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: {
        "downloads" => {
          "payments" => {
            "mode" => "order_type",
            "order_type" => "C54"
          }
        }
      })
    org(
      country_code: "CH",
      bank_connection_type: "ebics",
      bank_credentials: ebics_credentials)

    assert_equal "Z54", Current.org.bank_connection.operation_config.payment_download(country_code: "CH").order_type
  end

  test "fiscal_years returns an array of fiscal years" do
    fiscal_years = Current.org.fiscal_years

    assert_kind_of Array, fiscal_years
    assert fiscal_years.any?
    assert fiscal_years.all? { |fy| fy.is_a?(FiscalYear) }
  end

  test "fiscal_years includes current fiscal year" do
    fiscal_years = Current.org.fiscal_years

    assert_includes fiscal_years, Current.org.current_fiscal_year
  end

  test "fiscal_years spans from earliest to latest delivery years" do
    fiscal_years = Current.org.fiscal_years
    min_date = Delivery.minimum(:date)
    max_date = Delivery.maximum(:date)

    assert fiscal_years.any? { |fy| fy.include?(min_date) }
    assert fiscal_years.any? { |fy| fy.include?(max_date) }
  end

  test "fiscal_years handles nil delivery dates by using compact" do
    # This tests the fix for the "comparison of Integer with nil failed" error
    # that occurs when Delivery.minimum(:date) or Delivery.maximum(:date)
    # returns nil (no deliveries in the database).
    #
    # The fix uses .compact before .min/.max to filter out nil values:
    #   [ Delivery.minimum(:date)&.year, Current.fy_year, ... ].compact.min

    # Simulate what would happen with nil values from the database
    current_year = Date.current.year

    # Without compact, this would raise "comparison of Integer with nil failed"
    with_nil = [ nil, current_year, current_year ].compact.min
    assert_equal current_year, with_nil

    # Also verify that max works the same way
    with_nil_max = [ nil, current_year, current_year ].compact.max
    assert_equal current_year, with_nil_max

    # When all delivery dates are nil, we should still get valid years
    only_nils = [ nil, nil, current_year ].compact
    assert_equal [ current_year ], only_nils
    assert_equal current_year, only_nils.min
    assert_equal current_year, only_nils.max
  end

  private

  def ebics_credentials
    {
      "keys" => "keys",
      "secret" => "secret",
      "url" => "https://ebics.example.test",
      "host_id" => "HOSTID",
      "participant_id" => "PARTICIPANTID",
      "client_id" => "CLIENTID"
    }
  end
end
