# frozen_string_literal: true

class SocialNetwork
  attr_reader :url

  URLS = {
    facebook: %w[facebook fb.me],
    instagram: %w[instagram instagr.am],
    linkedin: %w[linkedin lnkd.in],
    pinterest: %w[pinterest pin.it],
    signal: %w[signal],
    snapchat: %w[snapchat],
    telegram: %w[telegram t.me],
    tiktok: %w[tiktok],
    whatsapp: %w[whatsapp],
    x: %w[x.com twitter t.co],
  }

  def initialize(url)
    @url = url
  end

  def valid?
    icon.present?
  end

  def url_valid?
    uri = URI.parse(url)
    uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  def icon
    URLS.find do |icon, urls|
      return icon if urls.any? { |u| url.include?(u) }
    end
  end
end
