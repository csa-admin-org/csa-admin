module Tenant
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      host = request.host.split(".")[-2]

      if tenant_name = ACP.find_by(host: host)&.tenant_name
        Tenant.switch(tenant_name) { @app.call(env) }
      else
        @app.call(env)
      end
    end
  end
end
