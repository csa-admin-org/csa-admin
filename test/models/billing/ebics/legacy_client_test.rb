# frozen_string_literal: true

require "test_helper"
require "epics"

class Billing::EBICS::LegacyClientTest < ActiveSupport::TestCase
  test "builds Epics client lazily from credentials" do
    factory = EpicsClientFactory.new
    client = Billing::EBICS::LegacyClient.new(credentials, client_factory: factory)

    assert_same factory.client, client.client
    assert_equal [
      "keys",
      "secret",
      "https://ebics.example.test",
      "HOSTID",
      "PARTICIPANTID",
      "CLIENTID"
    ], factory.new_args
  end

  test "downloads order-type operations through the Epics client" do
    epics_client = EpicsClientStub.new(z54: [ "file" ])
    client = Billing::EBICS::LegacyClient.new(credentials, epics_client: epics_client)

    assert_equal [ "file" ], client.download(Billing::EBICS::Operation.order_type("Z54"),
      from: "2026-06-01",
      to: "2026-07-01")
    assert_equal [ [ :Z54, [ "2026-06-01", "2026-07-01" ] ] ], epics_client.calls
  end

  test "uploads order-type operations through the Epics client" do
    epics_client = EpicsClientStub.new(cdd: [ "transaction-id", "order-id" ])
    client = Billing::EBICS::LegacyClient.new(credentials, epics_client: epics_client)

    assert_equal [ "transaction-id", "order-id" ], client.upload(
      Billing::EBICS::Operation.order_type("CDD"),
      document: "document")
    assert_equal [ [ :CDD, [ "document" ] ] ], epics_client.calls
  end

  test "maps no-data business errors to boundary errors" do
    epics_client = EpicsClientStub.new(z54: ::Epics::Error::BusinessError.new("090005"))
    client = Billing::EBICS::LegacyClient.new(credentials, epics_client: epics_client)

    error = assert_raises(Billing::EBICS::NoDownloadDataAvailable) do
      client.download(Billing::EBICS::Operation.order_type("Z54"), from: "2026-06-01", to: "2026-07-01")
    end

    assert_instance_of ::Epics::Error::BusinessError, error.original_error
  end

  test "maps technical errors to boundary errors" do
    epics_client = EpicsClientStub.new(z54: ::Epics::Error::TechnicalError.new("061099"))
    client = Billing::EBICS::LegacyClient.new(credentials, epics_client: epics_client)

    error = assert_raises(Billing::EBICS::TechnicalError) do
      client.download(Billing::EBICS::Operation.order_type("Z54"), from: "2026-06-01", to: "2026-07-01")
    end

    assert_instance_of ::Epics::Error::TechnicalError, error.original_error
  end

  test "rejects BTF operations while scoped to legacy H004" do
    client = Billing::EBICS::LegacyClient.new(credentials, epics_client: EpicsClientStub.new)
    operation = Billing::EBICS::Operation.btf({
      "order_type" => "BTD",
      "service_name" => "REP"
    })

    assert_raises(Billing::EBICS::UnsupportedOperation) do
      client.download(operation, from: "2026-06-01", to: "2026-07-01")
    end
  end

  test "shapes setup and finalization calls behind the legacy client" do
    factory = EpicsClientFactory.new
    client = Billing::EBICS::LegacyClient.setup(credentials.except("keys"), client_factory: factory)

    assert_equal [ "secret", "https://ebics.example.test", "HOSTID", "PARTICIPANTID", "CLIENTID", 2048 ], factory.setup_args
    assert client.submit_initialization!
    assert_equal "letter", client.ini_letter("CSA Admin")
    assert_equal [ "bank-x", "bank-e" ], client.fetch_bank_keys!
    assert_equal "keys-path", client.save_keys("keys-path")
    assert_equal [ :INI, :HIA, :ini_letter, :HPB, :save_keys ], factory.client.calls.map(&:first)
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

  class EpicsClientFactory
    attr_reader :client, :new_args, :setup_args

    def initialize
      @client = EpicsClientStub.new
    end

    def new(*args)
      @new_args = args
      client
    end

    def setup(*args)
      @setup_args = args
      client
    end
  end

  class EpicsClientStub
    attr_reader :calls

    def initialize(z54: [], cdd: nil)
      @responses = { Z54: z54, CDD: cdd }
      @calls = []
    end

    def Z54(*args)
      call(:Z54, args)
    end

    def CDD(*args)
      call(:CDD, args)
    end

    def INI
      call(:INI, [])
      true
    end

    def HIA
      call(:HIA, [])
      true
    end

    def ini_letter(bank_name)
      call(:ini_letter, [ bank_name ])
      "letter"
    end

    def HPB
      call(:HPB, [])
      [ "bank-x", "bank-e" ]
    end

    def save_keys(path)
      call(:save_keys, [ path ])
      path
    end

    private

    def call(name, args)
      @calls << [ name, args ]
      response = @responses[name]
      raise response if response.is_a?(Exception)

      response
    end
  end
end
