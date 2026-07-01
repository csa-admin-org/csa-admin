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
    client = EBICSClientStub.new(cdd: "order-id")

    with_current_org_error do
      with_epics_client(client) do
        assert_equal "order-id", Billing::EBICS.new(credentials).sepa_direct_debit_upload("document")
      end
    end
  end

  test "downloads Swiss payments with legacy Z54 order type" do
    org(country_code: "CH")
    client = EBICSClientStub.new(z54: [ file_fixture("camt054.xml") ])

    with_epics_client(client) do
      payments_data = Billing::EBICS.new(credentials).payments_data

      assert_equal [ :Z54 ], client.calls.map(&:first)
      assert_equal [ Billing::EBICS::GET_PAYMENTS_FROM.to_date.to_s, Date.current.to_s ], client.calls.first.last
      assert_equal "camt.054", payments_data.first.origin
    end
  end

  test "downloads non-Swiss payments with legacy C53 order type" do
    org(country_code: "DE")
    client = EBICSClientStub.new(c53: [ file_fixture("camt053.xml") ])

    with_epics_client(client) do
      payments_data = Billing::EBICS.new(credentials).payments_data

      assert_equal [ :C53 ], client.calls.map(&:first)
      assert_equal [ Billing::EBICS::GET_PAYMENTS_FROM.to_date.to_s, Date.current.to_s ], client.calls.first.last
      assert_equal "camt.053", payments_data.first.origin
    end
  end

  test "uploads SEPA direct debit with legacy CDD order type" do
    client = EBICSClientStub.new(cdd: "order-id")

    with_epics_client(client) do
      assert_equal "order-id", Billing::EBICS.new(credentials).sepa_direct_debit_upload("document")
    end

    assert_equal [ [ :CDD, [ "document" ] ] ], client.calls
  end

  test "returns no payments and notifies when no EBICS download data is available" do
    event = EventRecorder.new
    client = EBICSClientStub.new(z54: ::Epics::Error::BusinessError.new("090005"))

    with_rails_event(event) do
      with_epics_client(client) do
        assert_empty Billing::EBICS.new(credentials).payments_data
      end
    end

    assert_equal 1, event.notifications.size
    name, payload = event.notifications.first
    assert_equal :ebics_no_data_available, name
    assert_equal "Epics::Error::BusinessError", payload[:error]
    assert_includes payload[:error_message], "EBICS_NO_DOWNLOAD_DATA_AVAILABLE"
  end

  test "returns no payments and notifies when EBICS technical error occurs" do
    event = EventRecorder.new
    client = EBICSClientStub.new(z54: ::Epics::Error::TechnicalError.new("061099"))

    with_rails_event(event) do
      with_epics_client(client) do
        assert_empty Billing::EBICS.new(credentials).payments_data
      end
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
