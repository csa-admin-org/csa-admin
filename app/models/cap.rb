# frozen_string_literal: true

module Cap
  DEFAULT_API_URL = "https://cap.csa-admin.org"

  def self.api_url
    ENV.fetch("CAP_API_URL", DEFAULT_API_URL).delete_suffix("/")
  end

  def self.site_key(org = Current.org)
    development_site_key || org.cap_site_key
  end

  def self.secret_key(org = Current.org)
    development_secret_key || org.cap_secret_key
  end

  def self.development_site_key
    ENV["CAP_DEVELOPMENT_SITE_KEY"].presence if Rails.env.development?
  end

  def self.development_secret_key
    ENV["CAP_DEVELOPMENT_SECRET_KEY"].presence if Rails.env.development?
  end
end
