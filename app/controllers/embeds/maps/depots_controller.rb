# frozen_string_literal: true

require "ipaddr"
require "public_suffix"

module Embeds
  module Maps
    class DepotsController < ApplicationController
      OPEN_FREE_MAP_STYLE_URL = "https://tiles.openfreemap.org/styles/%<style>s"
      DEFAULT_MARKER_COLOR = "#2563eb"
      MARKER_COLOR_PATTERN = /\A#?(?:\h{3}|\h{6})\z/

      layout false

      after_action :set_embed_headers, only: :show

      def show
        return head :not_found unless Current.org.feature?("maps")

        expires_in 5.minutes, public: true
        @csp_nonce = csp_nonce
        @maps_style = maps_style
        @map_style_url = format(OPEN_FREE_MAP_STYLE_URL, style: @maps_style)
        @marker_color = marker_color
        @maplibre_locale = maplibre_locale
        @depot_groups = depot_groups
        @marker_groups = marker_groups
      end

      private

      def set_locale
        params_locale = params[:locale]&.first(2)
        I18n.locale =
          (params_locale.in?(I18n.available_locales.map(&:to_s)) && params_locale) ||
          Current.org.default_locale
      end

      def maplibre_locale
        {
          "CooperativeGesturesHandler.WindowsHelpText" => t("maps.maplibre.cooperative_gestures.windows_help_text"),
          "CooperativeGesturesHandler.MacHelpText" => t("maps.maplibre.cooperative_gestures.mac_help_text"),
          "CooperativeGesturesHandler.MobileHelpText" => t("maps.maplibre.cooperative_gestures.mobile_help_text")
        }
      end

      def depot_groups
        depot_scope
          .reorder_by_public_name
          .group_by { |depot| [ depot.latitude.round(4), depot.longitude.round(4) ] }
          .map { |(_latitude, _longitude), depots| depot_group(depots) }
      end

      def depot_group(depots)
        depot = depots.first
        { latitude: depot.latitude.to_f, longitude: depot.longitude.to_f, depots: depots }
      end

      def depot_scope
        scope = Depot.mapped
        return scope unless depot_ids_filter?
        return scope.none if depot_ids.empty?

        scope.where(id: depot_ids)
      end

      def depot_ids_filter?
        params.key?(:depot_ids)
      end

      def depot_ids
        @depot_ids ||= Array(params[:depot_ids])
          .flat_map { |ids| ids.to_s.split(",") }
          .filter_map { |id| Integer(id, exception: false) }
          .select(&:positive?)
      end

      def maps_style
        style = params[:style].presence || Current.org.maps_style
        style.in?(Organization.map_styles) ? style : Current.org.maps_style
      end

      def marker_color
        color = params[:marker_color].to_s
        color = DEFAULT_MARKER_COLOR unless color.match?(MARKER_COLOR_PATTERN)
        color = color.delete_prefix("#")
        color = color.chars.flat_map { |char| [ char, char ] }.join if color.length == 3

        "##{color.downcase}"
      end

      def marker_groups
        @depot_groups.map { |group| marker_group(group) }
      end

      def marker_group(group)
        {
          latitude: group[:latitude],
          longitude: group[:longitude],
          title: marker_title(group[:depots]),
          html: render_to_string(partial: "embeds/maps/depots/depot_group", formats: :html, locals: { depots: group[:depots] })
        }
      end

      def marker_title(depots)
        depots.map { |depot| helpers.strip_tags(depot.public_name) }.join(", ")
      end

      def set_embed_headers
        response.headers.delete("X-Frame-Options")
        response.headers["Content-Security-Policy"] = embed_content_security_policy
      end

      def embed_content_security_policy
        [
          "default-src 'self'",
          "base-uri 'none'",
          "object-src 'none'",
          "script-src 'self' 'nonce-#{csp_nonce}' https://unpkg.com",
          "style-src 'self' 'unsafe-inline' https://unpkg.com",
          "img-src 'self' data: blob: https://tiles.openfreemap.org",
          "connect-src 'self' https://tiles.openfreemap.org",
          "worker-src blob:",
          "frame-ancestors #{frame_ancestors}"
        ].join("; ")
      end

      def csp_nonce
        @csp_nonce ||= SecureRandom.base64(16)
      end

      def frame_ancestors
        return "*" if Rails.env.development?

        [ "'self'", *organization_origins ].join(" ")
      end

      def organization_origins
        uri = URI.parse(Current.org.url)
        return [] unless uri.scheme.in?(%w[http https]) && uri.host

        [ organization_origin(uri), organization_subdomain_origin(uri) ].compact.uniq
      rescue URI::InvalidURIError, PublicSuffix::Error, TypeError
        []
      end

      def organization_origin(uri)
        [ uri.scheme, "://", uri.host, organization_origin_port(uri) ].join
      end

      def organization_subdomain_origin(uri)
        domain = organization_domain(uri.host)
        return unless domain

        [ uri.scheme, "://*.", domain, organization_origin_port(uri) ].join
      end

      def organization_domain(host)
        return if ip_address?(host)

        PublicSuffix.parse(host).domain
      end

      def ip_address?(host)
        IPAddr.new(host)
        true
      rescue IPAddr::InvalidAddressError
        false
      end

      def organization_origin_port(uri)
        return if [ 80, 443 ].include?(uri.port)

        ":#{uri.port}"
      end
    end
  end
end
