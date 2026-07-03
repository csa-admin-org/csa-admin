# frozen_string_literal: true

require "test_helper"
require "epics"

class Billing::EBICSTest < ActiveSupport::TestCase
  test "initializes epics client with current credential keys" do
    args = nil
    client = EBICSClientStub.new

    with_epics_client_factory(->(*given_args) { args = given_args; client }) do
      assert_same client, Billing::EBICS.new(credentials).client
    end

    assert_equal [
      "keys",
      "secret",
      "https://ebics.example.test",
      "HOSTID",
      "PARTICIPANTID",
      "CLIENTID"
    ], args
  end

  test "client initialization does not require current organization" do
    client = EBICSClientStub.new

    with_current_org_error do
      with_epics_client(client) do
        assert_same client, Billing::EBICS.new(credentials).client
      end
    end
  end

  test "SEPA direct debit upload does not require current organization" do
    client = BtfClientStub.new([])

    with_current_org_error do
      assert_equal [ "TX123", "A001" ], Billing::EBICS
        .new(credentials, settings: upload_btf_settings, ebics_client: client)
        .sepa_direct_debit_upload("document")
    end
  end

  test "payment downloads require explicit BTF settings" do
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS.new(credentials).payments_data
    end

    assert_equal "Active EBICS payment_download must use explicit BTF settings", error.message
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
    connection = bank_connection(settings: settings)

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS.new(credentials, settings: settings, bank_connection: connection).process_payments!
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
    connection = bank_connection(settings: settings)

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

  test "explicit BTF settings use the H005 direct debit upload operation" do
    settings = {
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload
        }
      }
    }
    client = BtfClientStub.new([])

    assert_equal [ "TX123", "A001" ], Billing::EBICS
      .new(credentials, settings: settings, ebics_client: client)
      .sepa_direct_debit_upload("pain-xml")

    method, operation, document = client.calls.first
    assert_equal :upload, method
    assert operation.btf?
    assert_equal "BTU", operation.order_type
    assert_equal "pain.008", operation.btf.fetch("message_name")
    assert_equal "pain-xml", document
  end

  test "explicit BTF settings use the H005 payment download operation" do
    org(country_code: "CH")
    settings = btf_settings
    client = BtfClientStub.new([ file_fixture("camt054.xml") ])

    payments_data = Billing::EBICS.new(credentials, settings: settings, ebics_client: client).payments_data

    operation, range = client.calls.first
    assert operation.btf?
    assert_equal "BTD", operation.order_type
    assert_equal "camt.054", operation.btf.fetch("message_name")
    assert_equal [ Billing::EBICS::GET_PAYMENTS_FROM.to_date.to_s, Date.current.to_s ], range
    assert_equal "camt.054", payments_data.first.origin
  end

  test "process payments uses ACK-after-processor for BTF downloads" do
    org(country_code: "CH")
    client = BtfClientStub.new([ file_fixture("camt054.xml") ])

    assert Billing::EBICS.new(credentials, settings: btf_settings, ebics_client: client).process_payments!

    method, operation, range = client.calls.first
    assert_equal :download_and_process, method
    assert operation.btf?
    assert_equal "BTD", operation.order_type
    assert_equal [ Billing::EBICS::GET_PAYMENTS_FROM.to_date.to_s, Date.current.to_s ], range
  end

  test "process payments updates bank connection import status" do
    org(country_code: "CH")
    BankConnection.delete_all
    connection = bank_connection(settings: btf_settings)
    client = BtfClientStub.new([ file_fixture("camt054.xml") ])

    assert Billing::EBICS
      .new(credentials, settings: btf_settings, ebics_client: client, bank_connection: connection)
      .process_payments!

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
    error = Billing::EBICS::NoDownloadDataAvailable.new(::Epics::Error::BusinessError.new("090005"))
    client = BtfClientStub.new(error)

    with_rails_event(event) do
      assert_empty Billing::EBICS.new(credentials, settings: btf_settings, ebics_client: client).payments_data
    end

    assert_equal 1, event.notifications.size
    name, payload = event.notifications.first
    assert_equal :ebics_no_data_available, name
    assert_equal "Epics::Error::BusinessError", payload[:error]
    assert_includes payload[:error_message], "EBICS_NO_DOWNLOAD_DATA_AVAILABLE"
  end

  test "returns no payments and notifies when EBICS technical error occurs" do
    event = EventRecorder.new
    error = Billing::EBICS::TechnicalError.new(::Epics::Error::TechnicalError.new("061099"))
    client = BtfClientStub.new(error)

    with_rails_event(event) do
      assert_empty Billing::EBICS.new(credentials, settings: btf_settings, ebics_client: client).payments_data
    end

    assert_equal 1, event.notifications.size
    name, payload = event.notifications.first
    assert_equal :ebics_technical_error, name
    assert_equal "Epics::Error::TechnicalError", payload[:error]
    assert_includes payload[:error_message], "EBICS_INTERNAL_ERROR"
  end

  private

  def credentials
    {
      "keys" => "keys",
      "secret" => "secret",
      "url" => "https://ebics.example.test",
      "host_id" => "HOSTID",
      "participant_id" => "PARTICIPANTID",
      "client_id" => "CLIENTID"
    }
  end

  def btf_settings
    {
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
    }
  end

  def upload_btf_settings
    {
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "schema" => "pain.008.001.08",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(scope: "DE", container: "XML", version: nil)
        }
      }
    }
  end

  def bank_connection(settings:)
    BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: credentials,
      settings: settings)
  end

  def with_epics_client(client, &block)
    with_epics_client_factory(->(*_args) { client }, &block)
  end

  def with_epics_client_factory(factory)
    original = ::Epics::Client.method(:new)
    ::Epics::Client.define_singleton_method(:new) { |*args| factory.call(*args) }
    yield
  ensure
    ::Epics::Client.define_singleton_method(:new, original)
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

  class EBICSClientStub
    attr_reader :calls

    def initialize(z54: [], c53: [], cdd: nil)
      @responses = { Z54: z54, C53: c53, CDD: cdd }
      @calls = []
    end

    def Z54(*args)
      call(:Z54, args)
    end

    def C53(*args)
      call(:C53, args)
    end

    def CDD(*args)
      call(:CDD, args)
    end

    private

    def call(name, args)
      @calls << [ name, args ]
      response = @responses.fetch(name)
      raise response if response.is_a?(Exception)

      response
    end
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

    def download(operation, from:, to:)
      @calls << [ operation, [ from, to ] ]
      raise @files if @files.is_a?(Exception)

      @files
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

    def notify(name, **payload)
      @notifications << [ name, payload ]
    end
  end
end
