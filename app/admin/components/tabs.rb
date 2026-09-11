# frozen_string_literal: true

class Tabs < ActiveAdmin::Component
  builder_method :tabs

  def tab(title, options = {}, &block)
    title = title.to_s.titleize if title.is_a? Symbol
    options = options.dup
    assign_default_selection!(options)
    selected = options[:selected]
    @menu << build_menu_item(title, options, &block)
    options.delete(:html_options)
    @tabs_content << build_content_item(title, options.merge(selected: selected), &block)
  end

  def build(attributes = {}, &block)
    @selected_assigned = false
    super(attributes)
    add_class "tabs"
    set_attribute :data, controller: "tabs"
    @menu = nav(class: "tabs-nav", role: "tablist")
    @tabs_content = div(class: "tabs-content", id: "tabs-container-#{object_id}")
  end

  def build_menu_item(title, options, &block)
    hidden = options.delete(:hidden) || false
    fragment = options.fetch(:id, fragmentize(title))
    data_action = options.dig(:html_options, "data-action")
    html_options = options.fetch(:html_options, {}).merge(
      "data-tabs-hidden": hidden,
      "data-action": "click->tabs#switchTab #{data_action}",
      role: "tab",
      "aria-controls": fragment,
      "aria-selected": options.delete(:selected) || false,
      href: "##{fragment}")
    a html_options do
      title
    end
  end

  def build_content_item(title, options, &block)
    extra_class = options.delete(:class)
    selected = options.delete(:selected)
    options.delete(:hidden)
    options = options.reverse_merge(
      id: fragmentize(title),
      role: "tabpanel",
      "aria-labelledby": "#{title}-tab")
    options[:class] = [ extra_class, ("is-hidden" unless selected) ].flatten.compact.join(" ")
    options[:disabled] = true unless selected
    fieldset(options, &block)
  end

  private

  def assign_default_selection!(options)
    return if @selected_assigned
    return if options[:hidden]

    if options[:selected]
      @selected_assigned = true
    elsif !options.key?(:selected)
      options[:selected] = true
      @selected_assigned = true
    end
  end

  def fragmentize(string)
    "tabs-#{string.parameterize}-#{object_id}"
  end
end
