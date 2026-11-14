# frozen_string_literal: true

require "public_suffix"

module Tenant
  class Middleware
    # cdn is the logo/asset host, not a tenant. Local host lookup ignores the
    # TLD, so cdn.csa-admin.test and the apex csa-admin.test both match
    # demo-en's admin host. LogosController then cannot switch to the path tenant.
    APP_SUBDOMAINS = %w[query inbound mc cdn].freeze
    # Bare hosts for the Mission Control launcher under bin/dev
    # (DEV_ORIGIN=localhost) — shared with routes and mc_launcher_url.
    DEV_LAUNCHER_HOSTS = %w[127.0.0.1 localhost].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      if request.path == "/up" || app_host?(request) || development_launcher?(request)
        @app.call(env)
      elsif tenant = Tenant.find_by(host: request.host)
        Tenant.switch(tenant) { @app.call(env) }
      elsif app_domain?(request.host)
        @app.call(env)
      else
        [ 404, {}, [ "Not Found" ] ]
      end
    end

    private

    def app_host?(request)
      app_subdomain?(request) || local_app_apex?(request.host)
    end

    def app_subdomain?(request)
      APP_SUBDOMAINS.include?(request.subdomains.first)
    end

    # csa-admin.test has no subdomain, so it is not caught above. Its SLD still
    # collides with demo-en when the TLD is ignored.
    def local_app_apex?(host)
      return false unless Rails.env.local?

      parsed = PublicSuffix.parse(host)
      parsed.trd.nil? && parsed.sld == app_domain_sld
    rescue PublicSuffix::Error
      false
    end

    def app_domain_sld
      domain = Rails.app.creds.option(:app_domain).presence || "csa-admin.org"
      PublicSuffix.parse(domain).sld
    rescue PublicSuffix::Error
      "csa-admin"
    end

    def development_launcher?(request)
      Rails.env.development? && DEV_LAUNCHER_HOSTS.include?(request.host)
    end

    def app_domain?(host)
      PublicSuffix.parse(host).domain == Rails.app.creds.option(:app_domain)
    rescue PublicSuffix::Error
      false
    end
  end
end
