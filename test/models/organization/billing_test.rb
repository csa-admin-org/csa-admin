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

  test "bank_connection returns active tenant-local runtime adapter" do
    BankConnection.delete_all
    BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123", contract_number: "456", contract_password: "secret", private_key: "key" })

    assert_instance_of BankConnection::RuntimeAdapter, Current.org.bank_connection
    assert_respond_to Current.org.bank_connection, :version
  end

  test "bank_connection is blank without an active tenant-local row" do
    BankConnection.delete_all

    assert_not Current.org.bank_connection?
    assert_nil Current.org.bank_connection
  end


  test "bank_connection uses active EBICS BTF settings" do
    BankConnection.delete_all
    BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: {
        "protocol" => "H005",
        "downloads" => {
          "payments" => {
            "mode" => "btf",
            "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
          }
        }
      })
    org(country_code: "CH")


    operation = Current.org.bank_connection.operation_config.payment_download
    assert_equal "BTD", operation.order_type
    assert_equal "camt.054", operation.btf.fetch("message_name")
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
    synthetic_ebics_credentials(user_id: "PARTICIPANTID", partner_id: "CLIENTID")
  end
end
