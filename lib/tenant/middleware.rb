# frozen_string_literal: true

require "public_suffix"

module Tenant
  class Middleware
    APP_SUBDOMAINS = %w[query inbound].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      if request.path == "/up" || app_subdomain?(request)
        @app.call(env)
      elsif tenant = Tenant.find_by(host: request.host)
        Tenant.switch(tenant) { @app.call(env) }
      elsif app_domain?(request.host)
        @app.call(env)
      elsif (location = development_browser_redirect(request))
        [ 302, { "location" => location }, [] ]
      else
        [ 404, {}, [ "Not Found" ] ]
      end
    end

    private

    # Cursor opens the forwarded dev server at 127.0.0.1. That host is not a
    # tenant, so send the browser to DEV_BROWSER_HOST and keep the port the
    # browser used (the local forward is often not 3000).
    def development_browser_redirect(request)
      return unless Rails.env.development?
      return unless request.get? || request.head?
      return unless loopback_host?(request.host)

      host = ENV["DEV_BROWSER_HOST"].presence
      return if host.blank?

      uri = URI.parse(Tenant.local_url(host))
      "#{uri.scheme}://#{uri.host}:#{request.port}#{request.fullpath}"
    end

    def loopback_host?(host)
      %w[127.0.0.1 ::1 localhost].include?(host)
    end

    def app_subdomain?(request)
      APP_SUBDOMAINS.include?(request.subdomains.first)
    end

    def app_domain?(host)
      PublicSuffix.parse(host).domain == Rails.app.creds.option(:app_domain)
    rescue PublicSuffix::Error
      false
    end
  end
end
