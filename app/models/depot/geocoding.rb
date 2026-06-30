# frozen_string_literal: true

module Depot::Geocoding
  extend ActiveSupport::Concern

  ADDRESS_ATTRIBUTES = %w[address_name street zip city]

  included do
    scope :with_map_coordinates, ->(bool) {
      if ActiveModel::Type::Boolean.new.cast(bool)
        where.not(latitude: nil).where.not(longitude: nil)
      else
        where(latitude: nil).or(where(longitude: nil))
      end
    }

    after_commit :enqueue_geocoding, on: %i[create update]
  end

  class_methods do
    def ransackable_scopes(_auth_object = nil)
      super + %i[with_map_coordinates]
    end
  end

  def map_coordinates?
    latitude.present? && longitude.present?
  end

  def coordinates_missing?
    !map_coordinates?
  end

  def geocodable_address?(street: self.street, zip: self.zip, city: self.city)
    [ street, zip, city ].all?(&:present?)
  end

  def geocoding_address(street: self.street, zip: self.zip, city: self.city)
    return unless geocodable_address?(street: street, zip: zip, city: city)

    [ street, "#{zip} #{city}", Current.org.country&.iso_short_name ].compact_blank.join(", ")
  end

  def geocode_later(force: false)
    DepotGeocodingJob.perform_later(self, force: force) if ::Geocoding.enabled?
  end

  def geocode(force: false)
    return false unless force || coordinates_missing?

    coordinates = geocode_coordinates
    return false unless coordinates

    latitude, longitude = coordinates
    update!(latitude: latitude, longitude: longitude)
  end

  def geocode_coordinates(address = geocoding_address)
    return unless ::Geocoding.enabled?
    return if address.blank?

    result = ::Geocoding::Nominatim.search(address).first
    return unless result

    latitude, longitude = result.coordinates
    return unless latitude && longitude

    [ latitude, longitude ]
  rescue StandardError => error
    Rails.logger.warn("Depot geocoding failed for depot ##{id}: #{error.class}: #{error.message}")
    nil
  end

  private

  def enqueue_geocoding
    return unless ::Geocoding.enabled?
    return unless coordinates_missing? && geocodable_address?
    return unless (previous_changes.keys & ADDRESS_ATTRIBUTES).any?

    geocode_later
  end
end
