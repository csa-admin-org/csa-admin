# frozen_string_literal: true

module Cap
  DEFAULT_API_URL = "https://cap.csa-admin.org"

  def self.api_url
    Rails.app.creds.option(:cap_api_url, default: DEFAULT_API_URL).delete_suffix("/")
  end

  def self.internal_api_url
    Rails.app.creds.option(:cap_internal_api_url, default: api_url).delete_suffix("/")
  end

  def self.site_key(org = Current.org)
    development_site_key || org.cap_site_key
  end

  def self.secret_key(org = Current.org)
    development_secret_key || org.cap_secret_key
  end

  def self.development_site_key
    Rails.app.creds.option(:cap_development_site_key).presence if Rails.env.development?
  end

  def self.development_secret_key
    Rails.app.creds.option(:cap_development_secret_key).presence if Rails.env.development?
  end
end
