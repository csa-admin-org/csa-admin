# frozen_string_literal: true

require "public_suffix"

module Tenant
  class Middleware
    APP_SUBDOMAINS = %w[query inbound mc].freeze
    # Bare hosts for the Mission Control launcher under bin/dev
    # (DEV_ORIGIN=localhost) — shared with routes and mc_launcher_url.
    DEV_LAUNCHER_HOSTS = %w[127.0.0.1 localhost].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      if request.path == "/up" || app_subdomain?(request) || development_launcher?(request)
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

    def app_subdomain?(request)
      APP_SUBDOMAINS.include?(request.subdomains.first)
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
