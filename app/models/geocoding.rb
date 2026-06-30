# frozen_string_literal: true

module Geocoding
  def self.enabled?
    Rails.application.config.x.geocoding.enabled
  end
end
