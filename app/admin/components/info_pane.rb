# frozen_string_literal: true

class InfoPane < ActiveAdmin::Component
  builder_method :info_pane

  def build(icon_name = "information-circle", *args)
    args = args.extract_options!
    add_class args.delete(:class) if args.key?(:class)
    super(*args)
    add_class "mb-6 flex items-center gap-4 rounded-lg border border-dashed border-blue-800 bg-blue-50 p-3 pl-4 text-blue-800 dark:border-blue-300 dark:bg-blue-800 dark:text-blue-300"
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
