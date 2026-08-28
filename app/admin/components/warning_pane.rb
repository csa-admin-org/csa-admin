# frozen_string_literal: true

class WarningPane < ActiveAdmin::Component
  builder_method :warning_pane

  def build(icon_name = "triangle-alert", *args)
    args = args.extract_options!
    add_class args.delete(:class) if args.key?(:class)
    super(*args)
    add_class "admin-warning-pane"
    if icon_name.present?
      span(class: "admin-warning-pane-icon") { icon(icon_name) }
    end
    @contents = span
  end

  def add_child(child)
    if @contents
      @contents << child
    else
      super
    end
  end

  def children?
    @contents.children?
  end
end
