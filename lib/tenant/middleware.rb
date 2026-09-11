# frozen_string_literal: true

require "public_suffix"

module Tenant
  class Middleware
    APP_SUBDOMAINS = %w[query].freeze

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
      else
        [ 404, {}, [ "Not Found" ] ]
      end
    end

    private

    def app_subdomain?(request)
      APP_SUBDOMAINS.include?(request.subdomains.first)
    end

    def app_domain?(host)
      PublicSuffix.parse(host).domain == ENV["APP_DOMAIN"]
    rescue PublicSuffix::Error
      false
    end
  end
end
