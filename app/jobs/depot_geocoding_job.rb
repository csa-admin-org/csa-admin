# frozen_string_literal: true

class DepotGeocodingJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(*) { "nominatim-geocoding" }

  def perform(depot, force: false)
    depot.geocode(force: force)
  end
end
