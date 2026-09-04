# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Billing::BASTest < ActiveSupport::TestCase
  RSA_KEY = OpenSSL::PKey::RSA.generate(2048)

  test "autologin raises LoginError when STATUS is not I0000" do
    http = FakeHTTP.new
    http.add_response(code: "200", body: "<STATUS>E0001</STATUS>")

    assert_raises(Billing::BAS::LoginError) do
      with_http(http) { client.payments_data }
    end
  end

  test "autologin raises LoginError when challenge is missing" do
    http = FakeHTTP.new
    http.add_response(code: "200", body: "<STATUS>I0000</STATUS>")

    error = assert_raises(Billing::BAS::LoginError) do
      with_http(http) { client.payments_data }
    end

    assert_match(/missing challenge/, error.message)
  end

  test "payments_data does not report LoginError as unexpected" do
    http = FakeHTTP.new
    http.add_response(code: "200", body: "<STATUS>E0001</STATUS>")
    recorder = RailsErrorHelper::ErrorRecorder.new

    with_rails_error(recorder) do
      assert_raises(Billing::BAS::LoginError) do
        with_http(http) { client.payments_data }
      end
    end

    assert_empty recorder.unexpected_errors
    assert_empty recorder.reports
  end

  test "autologin raises UnknownError on empty 302" do
    http = FakeHTTP.new
    http.add_response(code: "302", body: "", headers: { "location" => "/authen/ui/app/error" })
    event = EventRecorder.new

    error = nil
    with_rails_event(event) do
      error = assert_raises(Billing::BAS::UnknownError) do
        with_http(http) { client.payments_data }
      end
    end

    assert_match(/unknown error/, error.message)
    name, payload = event.notifications.find { |n, _| n == :bas_unknown_error }
    assert_equal :bas_unknown_error, name
    assert_equal "/authen/ui/app/error", payload.fetch("location")
    assert_equal "302", payload.fetch("provider_status")
  end

  test "PASSWORD_RESET_URL points at the ABS self-service reset flow" do
    assert_equal(
      "https://wwwsec.abs.ch/authen/ui/app/self-service/flow/default-password-reset-flow/username",
      Billing::BAS::PASSWORD_RESET_URL)
  end

  test "verify_login! succeeds through the two autologin steps" do
    http = FakeHTTP.new
    http.add_response(code: "200", body: "<STATUS>I0000</STATUS><CHALLENGE>nonce</CHALLENGE>")
    http.add_response(
      code: "302",
      body: "<STATUS>I0000</STATUS>",
      headers: { "location" => "/ebanking/home" })
    http.add_response(code: "200", body: "ok")

    assert with_http(http) { client.verify_login! }
    assert_equal 3, http.requests.size
  end

  private

  def client
    Billing::BAS.new(
      account_number: "346.578.101-00",
      contract_number: "IB0043999",
      contract_password: "secret",
      private_key: RSA_KEY.to_pem)
  end

  def with_http(http, &block)
    Net::HTTP.stub(:new, http, &block)
  end

  def with_rails_event(event)
    original = Rails.method(:event)
    Rails.define_singleton_method(:event) { event }
    yield
  ensure
    Rails.define_singleton_method(:event, original)
  end

  class EventRecorder
    attr_reader :notifications

    def initialize
      @notifications = []
    end

    def notify(name, **payload)
      notifications << [ name, payload ]
    end
  end

  class FakeHTTP
    attr_accessor :use_ssl, :read_timeout, :open_timeout
    attr_reader :requests

    def initialize
      @requests = []
      @responses = []
    end

    def add_response(code:, body:, headers: {})
      @responses << FakeResponse.new(code, body, headers)
    end

    def request(req)
      @requests << req
      @responses.shift || FakeResponse.new("500", "", {})
    end
  end

  class FakeResponse
    attr_reader :body, :code

    def initialize(code, body, headers)
      @code = code.to_s
      @body = body
      @headers = headers.transform_keys { |key| key.to_s.downcase }
    end

    def [](key)
      @headers[key.to_s.downcase]
    end

    def get_fields(name)
      Array(@headers[name.to_s.downcase])
    end
  end
end
