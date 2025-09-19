# frozen_string_literal: true

require "test_helper"

class HasSocialNetworkUrlsTest < ActiveSupport::TestCase
  class DummyClass
    include ActiveModel::Model
    include ActiveModel::Attributes

    include HasSocialNetworkUrls

    attribute :social_network_urls
  end

  test "set social network urls" do
    dummy = DummyClass.new
    dummy.social_network_urls = "https://x.com/org, https://fb.me/org"

    assert_equal "https://x.com/org, https://fb.me/org", dummy.social_network_urls
    assert dummy.social_networks.all?(&:valid?)
    assert_equal %i[x facebook], dummy.social_networks.map(&:icon)
  end

  test "validate urls format" do
    dummy = DummyClass.new
    dummy.social_network_urls = "https://x.com/org"
    assert dummy.valid?(:social_network_urls)

    dummy = DummyClass.new
    dummy.social_network_urls = "https://x.com/org, argh"
    assert_not dummy.valid?(:social_network_urls)
    assert_includes dummy.errors.map(&:type), :invalid
  end

  test "validate social network urls" do
    dummy = DummyClass.new
    dummy.social_network_urls = "https://x.com/org"
    assert dummy.valid?(:social_network_urls)

    dummy = DummyClass.new
    dummy.social_network_urls = "https://x.com/org, https://foo.test"
    assert_not dummy.valid?(:social_network_urls)
    assert_includes dummy.errors.map(&:type), :unsupported_social_network_url
  end
end
