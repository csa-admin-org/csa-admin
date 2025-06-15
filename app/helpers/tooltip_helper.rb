# frozen_string_literal: true

module TooltipHelper
  def tooltip(id, text, icon_name: "information-circle")
    tooltip_id = "tooltip-#{id}"
    content_tag(:button,
      type: "button",
      class: "block z-20 hover:text-gray-900 dark:hover:text-gray-100",
      data: { "tooltip-target" => tooltip_id },
      onclick: "event.stopPropagation()"
    ) {
      icon icon_name, class: "size-5"
    } +
    content_tag(:div,
      id: tooltip_id,
      role: "tooltip",
      class: "absolute z-10 invisible inline-block max-w-96 px-3 py-2 text-sm font-medium text-white bg-gray-900 rounded-lg shadow-xs opacity-0 tooltip dark:bg-gray-700"
    ) {
      content_tag(:p, text) +
        content_tag(:div, nil, class: "tooltip-arrow text-left", data: { "popper-arrow" => true })
    }
  end
end
