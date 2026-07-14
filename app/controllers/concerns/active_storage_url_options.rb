# frozen_string_literal: true

module ActiveStorageUrlOptions
  extend ActiveSupport::Concern

  CLOUDFLARE_REDIRECT_CACHE_DURATION =
    ActiveStorage.service_urls_expire_in - 1.minute

  private

  def cache_active_storage_redirect
    # Thruster does not expose cache age, so only let Cloudflare cache redirects
    # within the service URL lifetime, retaining a safety margin.
    expires_now
    response.headers["Cloudflare-CDN-Cache-Control"] =
      "public, max-age=#{CLOUDFLARE_REDIRECT_CACHE_DURATION.to_i}, must-revalidate"
  end

  def set_active_storage_url_options
    ActiveStorage::Current.set(url_options: active_storage_url_options) { yield }
  end

  def active_storage_url_options
    {
      protocol: request.protocol,
      host: active_storage_url_host,
      port: request.optional_port
    }.compact
  end

  def active_storage_url_host
    Rails.env.local? ? request.host : Tenant.admin_host
  end
end
