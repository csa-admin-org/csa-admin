# frozen_string_literal: true

class Tabs < ActiveAdmin::Component
  builder_method :tabs

  def tab(title, options = {}, &block)
    title = title.to_s.titleize if title.is_a? Symbol
    @menu << build_menu_item(title, options, &block)
    options.delete(:html_options)
    @tabs_content << build_content_item(title, options, &block)
  end

  def build(attributes = {}, &block)
    super(attributes)
    add_class "tabs"
    set_attribute :data, controller: "tabs"
    @menu = nav(class: "tabs-nav", role: "tablist", "data-tabs-toggle": "#tabs-container-#{object_id}")
    @tabs_content = div(class: "tabs-content", id: "tabs-container-#{object_id}")
  end

  def build_menu_item(title, options, &block)
    hidden = options.delete(:hidden) || false
    fragment = options.fetch(:id, fragmentize(title))
    data_action = options.dig(:html_options, "data-action")
    html_options = options.fetch(:html_options, {}).merge(
      "data-tabs-hidden": hidden,
      "data-tabs-target": "##{fragment}",
      "data-action": "tabs#updateAnchor #{data_action}",
      role: "tab",
      "aria-controls": fragment,
      "aria-selected": options.delete(:selected) || false,
      href: "##{fragment}")
    a html_options do
      title
    end
  end

  def build_content_item(title, options, &block)
    options = options.reverse_merge(id: fragmentize(title), class: "hidden", role: "tabpanel", "aria-labelledby": "#{title}-tab")
    div(options, &block)
  end

  private

  def fragmentize(string)
    "tabs-#{string.parameterize}-#{object_id}"
  end
end
