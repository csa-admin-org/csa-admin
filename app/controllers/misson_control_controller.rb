# frozen_string_literal: true

class MissonControlController < ActionController::Base
  http_basic_authenticate_with name: "mc", password: ENV["MISSION_CONTROL_PASSWORD"]
end
