# frozen_string_literal: true

module TooltipHelper
  def tooltip(id, text, icon_name: "information-circle")
    tooltip_id = "tooltip-#{id}"
    content_tag(:a,
      class: "ms-1 block hover:text-gray-900 dark:hover:text-gray-100",
      data: { "tooltip-target" => tooltip_id }
    ) {
      icon icon_name, class: "h-5 w-5"
    } +
    content_tag(:div,
      id: tooltip_id,
      role: "tooltip",
      class: "absolute z-10 invisible inline-block max-w-96 px-3 py-2 text-sm font-medium text-white bg-gray-900 rounded-lg shadow-sm opacity-0 tooltip dark:bg-gray-700"
    ) {
      content_tag(:p, text) +
        content_tag(:div, nil, class: "tooltip-arrow", data: { "popper-arrow" => true })
    }
  end
end
