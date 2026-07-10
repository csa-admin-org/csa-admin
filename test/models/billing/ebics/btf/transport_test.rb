# frozen_string_literal: true

require "test_helper"
require "net/http"

class Billing::EBICS::Btf::TransportTest < ActiveSupport::TestCase
  test "streams successful HTTP response bodies" do
    transport = transport_for(response_with_chunks([ "first", " second" ]))

    assert_equal "first second", transport.post("https://ebics.example.test", "<request/>")
  end

  test "rejects oversized HTTP response bodies while streaming" do
    with_transport_limit(:MAX_RESPONSE_BYTES, 5) do
      transport = transport_for(response_with_chunks([ "123", "456" ]))

      error = assert_raises(Billing::EBICS::Btf::Transport::ResponseTooLarge) do
        transport.post("https://ebics.example.test", "<request/>")
      end

      assert_equal "EBICS HTTP response exceeds 5 bytes", error.message
    end
  end

  test "keeps bounded HTTP error bodies without exposing provider status text" do
    transport = transport_for(response_with_chunks([ "EBICS error" ], status: :error))

    error = assert_raises(Billing::EBICS::Btf::Transport::HTTPError) do
      transport.post("https://ebics.example.test", "<request/>")
    end

    assert_equal "HTTP 500", error.message
    assert_equal "EBICS error", error.body
  end

  private

  def transport_for(response)
    Billing::EBICS::Btf::Transport.new.tap do |transport|
      transport.define_singleton_method(:http) { |_uri| HTTPStub.new(response) }
    end
  end

  def response_with_chunks(chunks, status: :ok)
    response = case status
    when :ok then Net::HTTPOK.new("1.1", "200", "OK")
    when :error then Net::HTTPInternalServerError.new("1.1", "500", "Provider status text")
    end
    response.define_singleton_method(:read_body) do |&block|
      chunks.each(&block)
      nil
    end
    response
  end

  def with_transport_limit(name, value)
    transport = Billing::EBICS::Btf::Transport
    original = transport.const_get(name)
    transport.send(:remove_const, name)
    transport.const_set(name, value)
    yield
  ensure
    transport.send(:remove_const, name)
    transport.const_set(name, original)
  end

  class HTTPStub
    def initialize(response)
      @response = response
    end

    def request(_request)
      yield @response
      @response
    end
  end
end
