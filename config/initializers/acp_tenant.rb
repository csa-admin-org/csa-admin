require "tenant"
require "tenant/middleware"

Rails.application.config.middleware.use(Tenant::Middleware)

if Rails.env.test?
  require "tenant/test_middleware"
  Rails.application.config.middleware.unshift(Tenant::TestMiddleware)
end
