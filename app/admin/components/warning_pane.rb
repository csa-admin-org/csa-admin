# frozen_string_literal: true

class WarningPane < ActiveAdmin::Component
  builder_method :warning_pane

  def build(icon_name = "exclamation-triangle", *args)
    args = args.extract_options!
    add_class args.delete(:class) if args.key?(:class)
    super(*args)
    add_class "mb-6 flex items-center gap-4 rounded-lg border border-dashed border-orange-800 bg-orange-50 p-3 pl-4 text-orange-800 dark:border-orange-300 dark:bg-orange-800 dark:text-orange-300"
    if icon_name.present?
      span(class: "shrink-0") { icon(icon_name, class: "size-5") }
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
