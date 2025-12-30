# frozen_string_literal: true

module HasSocialNetworkUrls
  extend ActiveSupport::Concern

  included do
    validate :supported_social_network_urls
    validate :valid_social_network_urls
  end

  def social_network_urls
    super.join(", ")
  end

  def social_network_urls=(value)
    @social_networks = nil
    super(value.split(",").map(&:strip))
  end

  def social_networks
    @social_networks ||= social_network_urls.split(", ").map do |url|
      SocialNetwork.new(url)
    end
  end

  private

  def supported_social_network_urls
    return unless social_networks.all?(&:url_valid?)

    unless social_networks.all?(&:valid?)
      errors.add(:social_network_urls, :unsupported_social_network_url)
    end
  end

  def valid_social_network_urls
    unless social_networks.all?(&:url_valid?)
      errors.add(:social_network_urls, :invalid)
    end
  end
end
