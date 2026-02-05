# frozen_string_literal: true

module ActiveAdmin::DisabledButtonHelper
  # For action_items (header buttons)
  def disabled_action_button(label, tooltip:, icon_name:)
    tooltip_id = "tooltip-#{SecureRandom.hex(4)}"

    content_tag(:button,
      class: "h-9 action-item-button",
      disabled: true,
      data: { "tooltip-target" => tooltip_id, "tooltip-placement" => "bottom" }
    ) do
      icon(icon_name, class: "size-5 -ms-2 me-2") + label
    end +
    tooltip_element(tooltip_id, tooltip)
  end

  # For panel buttons (inline buttons in panels/sidebars)
  def disabled_button(label, tooltip:, icon_name: nil, btn_class: "btn btn-sm")
    tooltip_id = "tooltip-#{SecureRandom.hex(4)}"
    disabled_class = "#{btn_class} cursor-not-allowed"

    content_tag(:button,
      class: disabled_class,
      disabled: true,
      data: { "tooltip-target" => tooltip_id, "tooltip-placement" => "bottom" }
    ) do
      if icon_name
        icon(icon_name, class: "size-4 me-2") + label
      else
        label
      end
    end +
    tooltip_element(tooltip_id, tooltip)
  end
end
