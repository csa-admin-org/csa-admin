class TestACPElevator
  def initialize(app)
    @app = app
  end

  def call(env)
    previous_tenant = Apartment::Tenant.current

    if previous_tenant != 'public'
      Apartment::Tenant.reset
      resp = @app.call(env)
      resp[2] = ::Rack::BodyProxy.new(resp[2]) do
        Apartment::Tenant.switch!(previous_tenant)
      end
      resp
    else
      @app.call(env)
    end
  end
end
