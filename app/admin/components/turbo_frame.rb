# frozen_string_literal: true

class TurboFrame < ActiveAdmin::Component
  builder_method :turbo_frame

  def tag_name
    "turbo-frame"
  end
end
