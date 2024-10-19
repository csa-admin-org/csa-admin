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
      else
        @app.call(env)
      end
    end
  end
end
