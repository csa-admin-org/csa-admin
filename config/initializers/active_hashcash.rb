# frozen_string_literal: true

ActiveHashcash.base_controller_class = "ApplicationController"

# Below default 20, but safe given allow_browser minimum versions
ActiveHashcash.bits = Rails.env.production? ? 18 : 1
