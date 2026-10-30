# frozen_string_literal: true

Rails.application.config.x.geocoding.enabled = ActiveModel::Type::Boolean.new.cast(
  Rails.app.creds.option(:geocoding_enabled, default: (!Rails.env.test?).to_s))
Rails.application.config.x.geocoding.lookup = Rails.app.creds.option(:geocoder_lookup, default: "nominatim")
Rails.application.config.x.geocoding.user_agent = Rails.app.creds.option(
  :geocoder_user_agent,
  default: "CSA Admin (https://csa-admin.org; info@csa-admin.org)")
Rails.application.config.x.geocoding.timeout = Integer(Rails.app.creds.option(:geocoder_timeout, default: 5))
Rails.application.config.x.geocoding.minimum_interval = Rails.env.test? ? 0.seconds : 1.second

Geocoder.configure(
  lookup: Rails.application.config.x.geocoding.lookup.to_sym,
  timeout: Rails.application.config.x.geocoding.timeout,
  units: :km,
  http_headers: {
    "User-Agent" => Rails.application.config.x.geocoding.user_agent
  },
  cache: Rails.cache,
  cache_prefix: "geocoder:"
)
