# frozen_string_literal: true

module Rack
  class CatchBadMultipart
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Rack::Multipart::BoundaryTooLongError
      [ 400, { "content-type" => "text/plain" }, [ "Bad Request" ] ]
    end
  end
end
