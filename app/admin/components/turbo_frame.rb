# frozen_string_literal: true

# Arbre component for rendering <turbo-frame> elements in ActiveAdmin DSL.
#
# Usage:
#   turbo_frame id: "my-frame", data: { action: "turbo:frame-load->ctrl#method" } do
#     ul do
#       li "item"
#     end
#   end
class TurboFrame < ActiveAdmin::Component
  builder_method :turbo_frame

  def tag_name
    "turbo-frame"
  end
end
