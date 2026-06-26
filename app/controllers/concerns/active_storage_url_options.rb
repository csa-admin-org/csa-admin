# frozen_string_literal: true

module ActiveStorageUrlOptions
  extend ActiveSupport::Concern

  private

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
