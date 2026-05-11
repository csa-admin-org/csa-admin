# frozen_string_literal: true

module TooltipHelper
  def tooltip(id, text, icon_name: "info", icon_class: "size-5")
    tooltip_id = "tooltip-#{id}"

    content_tag(:span,
      class: "relative inline-flex",
      data: { controller: "tooltip" }
    ) do
      content_tag(:button,
        type: "button",
        class: "block z-20 hover:text-gray-900 dark:hover:text-gray-100",
        data: {
          "tooltip-target" => "trigger",
          action: "mouseenter->tooltip#show mouseleave->tooltip#hide focus->tooltip#show blur->tooltip#hide"
        },
        aria: { describedby: tooltip_id },
        onclick: "event.stopPropagation()"
      ) {
        icon icon_name, class: icon_class
      } +
      tooltip_element(text, id: tooltip_id)
    end
  end

  def popover(id, icon_name: "info", icon_class: "size-5", &block)
    popover_id = "popover-#{id}"

    content_tag(:span,
      class: "relative inline-flex",
      data: { controller: "tooltip", "tooltip-dismissible-value" => true }
    ) do
      content_tag(:button,
        type: "button",
        class: "block z-0 cursor-pointer hover:text-gray-900 dark:hover:text-gray-100",
        data: {
          "tooltip-target" => "trigger",
          action: "click->tooltip#toggle"
        },
        aria: { controls: popover_id, expanded: false },
        onclick: "event.stopPropagation()"
      ) {
        icon icon_name, class: icon_class
      } +
      popover_element(id: popover_id, &block)
    end
  end

  def tooltip_element(content, id: nil)
    _floating_element(id: id) { content_tag(:p, content) }
  end

  def popover_element(id: nil, &block)
    _floating_element(id: id) { capture(&block) }
  end

  private

  def _floating_element(id: nil)
    html_options = {
      role: "tooltip",
      class: "invisible fixed z-50 w-max max-w-96 px-3 py-2 text-sm font-medium text-white bg-gray-900 rounded-lg shadow-xs opacity-0 transition-opacity duration-150 tooltip dark:bg-gray-700",
      data: { "tooltip-target" => "content" }
    }
    html_options[:id] = id if id
    content_tag(:div, **html_options) do
      yield + content_tag(:div, nil, class: "tooltip-arrow", data: { "tooltip-target" => "arrow" })
    end
  end
end
