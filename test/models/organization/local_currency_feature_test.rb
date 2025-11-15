# frozen_string_literal: true

require "test_helper"

class LocalCurrencyFeatureTest < ActiveSupport::TestCase
  test "local_currency_wallet= strips comchain: prefix" do
    org = Organization.new
    org.local_currency_wallet = "comchain:1234567890abcdef"
    assert_equal "1234567890abcdef", org.local_currency_wallet
  end

  test "local_currency_wallet= strips 0x prefix" do
    org = Organization.new
    org.local_currency_wallet = "0x1234567890abcdef"
    assert_equal "1234567890abcdef", org.local_currency_wallet
  end

  test "local_currency_wallet= does not strip other prefixes" do
    org = Organization.new
    org.local_currency_wallet = "other:1234567890abcdef"
    assert_equal "other:1234567890abcdef", org.local_currency_wallet
  end

  test "local_currency_wallet= handles nil" do
    org = Organization.new
    org.local_currency_wallet = nil
    assert_nil org.local_currency_wallet
  end

  test "local_currency_secret= does not set value if all asterisks" do
    org = Organization.new
    org.local_currency_secret = "secret"
    assert_equal "secret", org.local_currency_secret

    org.local_currency_secret = "*******"
    assert_equal "secret", org.local_currency_secret  # should not change
  end

  test "local_currency_secret= sets value if not all asterisks" do
    org = Organization.new
    org.local_currency_secret = "newsecret"
    assert_equal "newsecret", org.local_currency_secret
  end

  test "local_currency_secret= handles nil" do
    org = Organization.new
    org.local_currency_secret = nil
    assert_nil org.local_currency_secret
  end

  test "local_currency_secret= handles empty string" do
    org = Organization.new
    org.local_currency_secret = ""
    assert_equal "", org.local_currency_secret
  end
end
