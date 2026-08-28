# frozen_string_literal: true

module TooltipHelper
  def tooltip(id, text, icon_name: "info", icon_class: "tooltip-icon", trigger_class: nil, &block)
    tooltip_id = "tooltip-#{id}"
    # Use a span (not button) so the trigger stays valid inside Formtastic
    # <p class="inline-hints"> wrappers and similar phrasing contexts.
    trigger_classes = [ "tooltip-trigger", trigger_class ].compact.join(" ")

    content_tag(:span,
      class: "tooltip-wrap",
      data: { controller: "tooltip" }
    ) do
      content_tag(:span,
        class: trigger_classes,
        tabindex: 0,
        role: "button",
        data: {
          "tooltip-target" => "trigger",
          action: "mouseenter->tooltip#show mouseleave->tooltip#hide focus->tooltip#show blur->tooltip#hide"
        },
        aria: { describedby: tooltip_id },
        onclick: "event.stopPropagation()"
      ) {
        if block
          capture(&block)
        else
          icon icon_name, class: icon_class
        end
      } +
      tooltip_element(text, id: tooltip_id)
    end
  end

  def popover(id, icon_name: "info", icon_class: "tooltip-icon", hover: false, &block)
    popover_id = "popover-#{id}"
    actions = [ "click->tooltip#toggle" ]
    actions += %w[
      mouseenter->tooltip#preview
      mouseleave->tooltip#hidePreview
      focus->tooltip#preview
      blur->tooltip#hidePreview
    ] if hover

    content_tag(:span,
      class: "tooltip-wrap",
      data: { controller: "tooltip", "tooltip-dismissible-value" => true }
    ) do
      content_tag(:button,
        type: "button",
        class: "tooltip-trigger is-clickable",
        data: {
          "tooltip-target" => "trigger",
          action: actions.join(" ")
        },
        aria: { controls: popover_id, expanded: false },
        onclick: "event.stopPropagation()"
      ) {
        icon icon_name, class: icon_class
      } +
      popover_element(id: popover_id, hover: hover, &block)
    end
  end

  def tooltip_element(content, id: nil)
    # span (not p/div): valid phrasing content inside Formtastic <p class="inline-hints">
    _floating_element(id: id) { content_tag(:span, content, class: "tooltip-body") }
  end

  def popover_element(id: nil, hover: false, &block)
    actions = %w[
      mouseenter->tooltip#cancelHidePreview
      mouseleave->tooltip#hidePreview
      focusin->tooltip#cancelHidePreview
      focusout->tooltip#hidePreview
    ] if hover

    _floating_element(id: id, action: actions&.join(" "), tag: :div) { capture(&block) }
  end

  private

  def _floating_element(id: nil, action: nil, tag: :span)
    data = { "tooltip-target" => "content" }
    data[:action] = action if action

    html_options = {
      role: "tooltip",
      class: "tooltip",
      data: data
    }
    html_options[:id] = id if id
    content_tag(tag, **html_options) do
      yield + content_tag(:span, nil, class: "tooltip-arrow", data: { "tooltip-target" => "arrow" })
    end
  end
end
