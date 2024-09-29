# frozen_string_literal: true

if ENV["MAINTENANCE_MODE"] == "ON"
  use Rack::Static, urls: [ "/maintenance.html" ], root: "public"

  run lambda { |env|
    case env["PATH_INFO"] # request path
    when "/up"
      [
        200, # HTTP status code for OK
        { "Content-Type" => "text/plain", "Content-Length" => "2" },
        [ "OK" ]
      ]
    else
      [
        503, # HTTP status code for Service Unavailable
        { "Content-Type" => "text/html", "Content-Length" => ::File.size("public/maintenance.html").to_s },
        [ ::File.read("public/maintenance.html") ]
      ]
    end
  }
else
  # Fallback to the usual Rails app
  require_relative "config/environment"

  use Rack::Status
  run Rails.application
  Rails.application.load_server
end
