# frozen_string_literal: true

module MapsHelper
  MAPLIBRE_VERSION = "5"
  MAPLIBRE_CDN_BASE_URL = "https://unpkg.com/maplibre-gl@#{MAPLIBRE_VERSION}/dist"
  OPEN_FREE_MAP_STYLE_URL = "https://tiles.openfreemap.org/styles/%<style>s"
  DEFAULT_DEPOT_MARKER_COLOR = "#16a34a"

  def display_position(latitude, longitude)
    return unless latitude && longitude

    link_to [ latitude, longitude ].join(", "), "https://www.google.com/maps?q=#{latitude},#{longitude}"
  end

  def open_free_map_style_url(style = Current.org.maps_style)
    style = Current.org.maps_style unless style.in?(Organization.map_styles)
    format(OPEN_FREE_MAP_STYLE_URL, style: style)
  end

  def maplibre_stylesheet_url
    "#{MAPLIBRE_CDN_BASE_URL}/maplibre-gl.css"
  end

  def maplibre_script_url
    "#{MAPLIBRE_CDN_BASE_URL}/maplibre-gl.js"
  end

  def maplibre_locale
    {
      "CooperativeGesturesHandler.WindowsHelpText" => t("maps.maplibre.cooperative_gestures.windows_help_text"),
      "CooperativeGesturesHandler.MacHelpText" => t("maps.maplibre.cooperative_gestures.mac_help_text"),
      "CooperativeGesturesHandler.MobileHelpText" => t("maps.maplibre.cooperative_gestures.mobile_help_text")
    }
  end

  def default_depot_marker_color
    DEFAULT_DEPOT_MARKER_COLOR
  end

  def public_depot_marker(depot)
    {
      id: depot.id,
      latitude: depot.latitude.to_f,
      longitude: depot.longitude.to_f,
      title: strip_tags(depot.public_name)
    }
  end

  def public_depot_markers(depots)
    depots.select(&:map_coordinates?).map { |depot| public_depot_marker(depot) }
  end
end
