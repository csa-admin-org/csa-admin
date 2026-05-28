# frozen_string_literal: true

require_relative "../../lib/rack/catch_bad_multipart"

Rails.application.config.middleware.insert_before Rack::MethodOverride, Rack::CatchBadMultipart
