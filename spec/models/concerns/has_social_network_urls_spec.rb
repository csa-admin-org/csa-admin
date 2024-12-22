
# frozen_string_literal: true

require "rails_helper"

describe HasSocialNetworkUrls do
  class DummyClass
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include HasSocialNetworkUrls

    attribute :social_network_urls
  end
  let(:dummy) { DummyClass.new }

  specify "set social network urls" do
    dummy.social_network_urls = "https://x.com/org, https://fb.me/org"

    expect(dummy.social_network_urls).to eq "https://x.com/org, https://fb.me/org"
    expect(dummy.social_networks).to all(be_valid)
    expect(dummy.social_networks.map(&:icon)).to eq %i[x facebook]
  end

  specify "validate urls format" do
    dummy.social_network_urls = "https://x.com/org"
    expect(dummy).to have_valid(:social_network_urls)

    dummy.social_network_urls = "https://x.com/org, argh"
    expect(dummy).not_to have_valid(:social_network_urls)

    expect(dummy.errors.map(&:type)).to include(:invalid)
  end

  specify "validate social network urls" do
    dummy.social_network_urls = "https://x.com/org"
    expect(dummy).to have_valid(:social_network_urls)

    dummy.social_network_urls = "https://x.com/org, https://foo.test"
    expect(dummy).not_to have_valid(:social_network_urls)

    expect(dummy.errors.map(&:type)).to include(:unsupported_social_network_url)
  end
end
