# frozen_string_literal: true

require "tenant"
require "tenant/middleware"

Rails.application.config.middleware.use Tenant::Middleware
