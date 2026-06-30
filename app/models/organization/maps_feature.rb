# frozen_string_literal: true

module Organization::MapsFeature
  extend ActiveSupport::Concern

  MAP_STYLES = %w[
    positron
    bright
    liberty
    dark
    fiord
  ]

  included do
    validates :maps_style, presence: true, inclusion: { in: MAP_STYLES }
  end

  def member_form_depot_map_enabled?
    feature?("maps") && member_form_depot_map?
  end

  class_methods do
    def map_styles = MAP_STYLES
  end
end
