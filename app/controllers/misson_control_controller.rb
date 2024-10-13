# frozen_string_literal: true

class MissonControlController < ActionController::Base
  if password = ENV["MISSION_CONTROL_PASSWORD"]
    http_basic_authenticate_with name: "mc", password: password
  end
end
