# frozen_string_literal: true

module Tenant
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      if tenant = Tenant.find_by(host: request.host)
        Tenant.switch(tenant) { @app.call(env) }
      elsif request.path == "/up"
        @app.call(env)
      elsif PublicSuffix.parse(request.host).domain == ENV["APP_DOMAIN"]
        @app.call(env)
      else
        [ 404, {}, [ "Not Found" ] ]
      end
    end
  end
end
