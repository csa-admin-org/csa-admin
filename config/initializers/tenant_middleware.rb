# frozen_string_literal: true

require "tenant"
require "tenant/middleware"

if Rails.env.development?
  Rails.application.config.middleware.insert_before WebConsole::Middleware, Tenant::Middleware
else
  Rails.application.config.middleware.use Tenant::Middleware
end
