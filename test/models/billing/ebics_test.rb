# frozen_string_literal: true

require "test_helper"

class Billing::EBICSTest < ActiveSupport::TestCase
  test "SEPA direct debit upload does not require current organization" do
    client = BtfClientStub.new([])

    with_current_org_error do
      assert_equal [ "TX123", "A001" ], Billing::EBICS
        .new(credentials, settings: upload_btf_settings, ebics_client: client)
        .sepa_direct_debit_upload("document")
    end
  end

  test "process payments require explicit BTF settings" do
    with_rails_env("production") do
      error = assert_raises(Billing::EBICS::UnsupportedOperation) do
        Billing::EBICS.new(credentials).process_payments!
      end

      assert_equal "Active EBICS payment_download must use explicit BTF settings", error.message
    end
  end

  test "process payments is production-only" do
    client = BtfClientStub.new([ file_fixture("camt054.xml") ])

    with_rails_env("development") do
      assert_nil Billing::EBICS.new(credentials, settings: btf_settings, ebics_client: client).process_payments!
    end

    assert_empty client.calls
  end

  test "process payments marks legacy payment download settings as configuration errors" do
    BankConnection.delete_all
    settings = {
      "downloads" => {
        "payments" => {
          "mode" => "order_type",
          "order_type" => "Z54"
        }
      }
    }
    connection = bank_connection(settings: settings, legacy_persisted: true)

    error = with_rails_env("production") do
      assert_raises(Billing::EBICS::UnsupportedOperation) do
        Billing::EBICS.new(credentials, settings: settings, bank_connection: connection).process_payments!
      end
    end

    assert_equal "Active EBICS payment_download must use explicit BTF settings", error.message
    connection.reload
    assert_equal "errored", connection.health_status
    assert_equal "Billing::EBICS::UnsupportedOperation", connection.last_error_class
    assert_equal "payment_download", connection.status_details.dig("last_error", "operation_kind")
  end

  test "SEPA direct debit upload marks legacy settings as configuration errors" do
    BankConnection.delete_all
    settings = {
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "order_type",
          "order_type" => "CDD"
        }
      }
    }
    connection = bank_connection(settings: settings, legacy_persisted: true)

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS.new(credentials, settings: settings, bank_connection: connection).sepa_direct_debit_upload("document")
    end

    assert_equal "Active EBICS sepa_direct_debit_upload must use explicit BTF settings", error.message
    connection.reload
    assert_equal "errored", connection.health_status
    assert_equal "Billing::EBICS::UnsupportedOperation", connection.last_error_class
    assert_equal "sepa_direct_debit_upload", connection.status_details.dig("last_error", "operation_kind")
  end

  test "reports configured SEPA direct debit PAIN schema" do
    settings = upload_btf_settings

    assert_equal "pain.008.001.08", Billing::EBICS.new(credentials, settings: settings).sepa_direct_debit_schema
  end

  test "explicit BTF settings send raw PAIN through the non-container upload operation" do
    client = BtfClientStub.new([])

    assert_equal [ "TX123", "A001" ], Billing::EBICS
      .new(credentials, settings: upload_btf_settings, ebics_client: client)
      .sepa_direct_debit_upload("pain-xml")

    method, operation, document = client.calls.first
    assert_equal :upload, method
    assert_equal "BTU", operation.order_type
    assert_equal "pain.008", operation.btf.fetch("message_name")
    assert_not operation.btf.key?("scope")
    assert_not operation.btf.key?("container")
    assert_equal "pain-xml", document
  end

  test "SEPA direct debit upload refuses XML-container settings before sending raw PAIN" do
    settings = upload_btf_settings.deep_merge(
      "uploads" => {
        "sepa_direct_debit" => {
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(
            scope: "DE",
            container: "XML",
            version: nil)
        }
      })
    client = BtfClientStub.new([])

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS.new(credentials, settings: settings, ebics_client: client)
        .sepa_direct_debit_upload("pain-xml")
    end

    assert_equal "EBICS BTF SEPA direct debit uploads require a non-container service", error.message
    assert_empty client.calls
  end

  test "process payments uses ACK-after-processor for BTF downloads" do
    org(country_code: "CH")
    client = BtfClientStub.new([ file_fixture("camt054.xml") ])

    with_rails_env("production") do
      assert Billing::EBICS.new(credentials, settings: btf_settings, ebics_client: client).process_payments!
    end

    method, operation, range = client.calls.first
    assert_equal :download_and_process, method
    assert_equal "BTD", operation.order_type
    assert_equal [ Billing::EBICS::GET_PAYMENTS_FROM.ago.to_date.to_s, Date.current.to_s ], range
  end

  test "process payments updates bank connection import status" do
    org(country_code: "CH")
    BankConnection.delete_all
    connection = bank_connection(settings: btf_settings)
    client = BtfClientStub.new([ file_fixture("camt054.xml") ])

    with_rails_env("production") do
      assert Billing::EBICS
        .new(credentials, settings: btf_settings, ebics_client: client, bank_connection: connection)
        .process_payments!
    end

    connection.reload
    assert_equal "healthy", connection.health_status
    assert connection.last_import_attempted_at?
    assert connection.last_import_succeeded_at?
    assert connection.last_health_check_at?
    assert_nil connection.last_error_class
    assert_equal 1, connection.status_details.dig("last_import", "files_count")
    assert_equal "BTD", connection.status_details.dig("last_import", "operation", "order_type")
  end

  test "SEPA direct debit upload updates bank connection upload status" do
    BankConnection.delete_all
    settings = upload_btf_settings
    connection = bank_connection(settings: settings)
    client = BtfClientStub.new([])

    result = Billing::EBICS
      .new(credentials, settings: settings, ebics_client: client, bank_connection: connection)
      .sepa_direct_debit_upload("pain-xml")

    assert_equal [ "TX123", "A001" ], result
    connection.reload
    assert_equal "healthy", connection.health_status
    assert connection.last_upload_attempted_at?
    assert connection.last_upload_succeeded_at?
    assert connection.last_health_check_at?
    assert_nil connection.last_error_class
    assert_equal "A001", connection.status_details.dig("last_upload", "order_id")
    assert_equal "BTU", connection.status_details.dig("last_upload", "operation", "order_type")
  end

  test "returns no payments and notifies when no EBICS download data is available" do
    event = EventRecorder.new
    error = Billing::EBICS::NoDownloadDataAvailable.new(StandardError.new("EBICS_NO_DOWNLOAD_DATA_AVAILABLE"))
    client = BtfClientStub.new(error)

    with_rails_event(event) do
      with_rails_env("production") do
        assert Billing::EBICS.new(credentials, settings: btf_settings, ebics_client: client).process_payments!
      end
    end

    _name, payload = event.notifications.find { |name, _payload| name == :ebics_no_data_available }
    assert_equal "StandardError", payload[:error_class]
    assert_not_includes payload.to_json, "EBICS_NO_DOWNLOAD_DATA_AVAILABLE"
  end

  test "returns no payments and notifies when EBICS technical error occurs" do
    event = EventRecorder.new
    error = Billing::EBICS::TechnicalError.new(StandardError.new("EBICS_INTERNAL_ERROR"))
    client = BtfClientStub.new(error)

    with_rails_event(event) do
      with_rails_env("production") do
        assert Billing::EBICS.new(credentials, settings: btf_settings, ebics_client: client).process_payments!
      end
    end

    _name, payload = event.notifications.find { |name, _payload| name == :ebics_technical_error }
    assert_equal "StandardError", payload[:error_class]
    assert_not_includes payload.to_json, "EBICS_INTERNAL_ERROR"
  end

  private

  def credentials
    @credentials ||= synthetic_ebics_credentials(
      user_id: "PARTICIPANTID",
      partner_id: "CLIENTID")
  end

  def btf_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
    }
  end

  def upload_btf_settings
    btf_settings.deep_merge(
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "schema" => "pain.008.001.08",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(version: nil)
        }
      })
  end

  def bank_connection(settings:, legacy_persisted: false)
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: credentials,
      settings: settings)

    if legacy_persisted
      # Runtime checks must diagnose legacy persisted configurations without permitting new ones.
      connection.save!(validate: false)
    else
      connection.save!
    end

    connection
  end



  def with_rails_event(event)
    original = Rails.method(:event)
    Rails.define_singleton_method(:event) { event }
    yield
  ensure
    Rails.define_singleton_method(:event, original)
  end

  def with_current_org_error
    original = Current.method(:org)
    Current.define_singleton_method(:org) { raise "Current.org should not be used" }
    yield
  ensure
    Current.define_singleton_method(:org, original)
  end



  class BtfClientStub
    attr_reader :calls

    def initialize(files)
      @files = files
      @calls = []
    end

    def upload(operation, document:)
      @calls << [ :upload, operation, document ]
      [ "TX123", "A001" ]
    end

    def download_and_process(operation, from:, to:)
      @calls << [ :download_and_process, operation, [ from, to ] ]
      raise @files if @files.is_a?(Exception)

      yield @files
    end
  end

  class EventRecorder
    attr_reader :notifications

    def initialize
      @notifications = []
    end

    def notify(name, payload = nil, **attributes)
      @notifications << [ name, (payload || {}).merge(attributes) ]
    end
  end
end
