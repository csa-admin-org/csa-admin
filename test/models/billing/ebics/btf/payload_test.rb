# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::Btf::PayloadTest < ActiveSupport::TestCase
  test "limits the number of encrypted order data segments" do
    with_payload_limit(:MAX_ORDER_DATA_SEGMENTS, 1) do
      error = assert_raises(Billing::EBICS::Btf::Payload::PayloadTooLarge) do
        payload_with_segments("one", "two").order_data
      end

      assert_equal "EBICS order data has too many segments", error.message
    end
  end

  test "limits encrypted order data before decryption" do
    with_payload_limit(:MAX_ENCRYPTED_ORDER_DATA_BYTES, 1) do
      error = assert_raises(Billing::EBICS::Btf::Payload::PayloadTooLarge) do
        payload_with_segments("12").order_data
      end

      assert_equal "EBICS encrypted order data exceeds 1 bytes", error.message
    end
  end

  private

  def payload_with_segments(*segments)
    Billing::EBICS::Btf::Payload.new(
      responses: segments.map { |segment| ResponseStub.new(segment) })
  end

  def with_payload_limit(name, value)
    payload = Billing::EBICS::Btf::Payload
    original = payload.const_get(name)
    payload.send(:remove_const, name)
    payload.const_set(name, value)
    yield
  ensure
    payload.send(:remove_const, name)
    payload.const_set(name, original)
  end

  class ResponseStub
    def initialize(encrypted_order_data)
      @encrypted_order_data = encrypted_order_data
    end

    def order_data_present? = true
    def transaction_key_present? = true
    def order_data_encrypted = @encrypted_order_data
    def transaction_key = "1234567890abcdef"
  end
end
