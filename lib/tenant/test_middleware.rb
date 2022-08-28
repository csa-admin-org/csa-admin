module Tenant
  class TestMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if Tenant.inside?
        previous_tenant = Tenant.current
        Tenant.reset
        resp = @app.call(env)
        resp[2] = ::Rack::BodyProxy.new(resp[2]) do
          Tenant.switch!(previous_tenant)
        end
        resp
      else
        @app.call(env)
      end
    end
  end
end
