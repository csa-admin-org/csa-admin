# frozen_string_literal: true

Rails.application.config.x.geocoding.enabled = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("GEOCODING_ENABLED", !Rails.env.test?))
Rails.application.config.x.geocoding.lookup = ENV.fetch("GEOCODER_LOOKUP", "nominatim")
Rails.application.config.x.geocoding.user_agent = ENV.fetch(
  "GEOCODER_USER_AGENT",
  "CSA Admin (https://csa-admin.org; info@csa-admin.org)")
Rails.application.config.x.geocoding.timeout = Integer(ENV.fetch("GEOCODER_TIMEOUT", 5))
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
