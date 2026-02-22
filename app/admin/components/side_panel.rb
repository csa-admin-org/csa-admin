# frozen_string_literal: true

class SidePanel < ActiveAdmin::Component
  builder_method :side_panel

  def build(title, *args)
    args = args.extract_options!
    action = args.delete(:action) if args.key?(:action)
    add_class args.delete(:class) if args.key?(:class)
    super(*args)
    add_class "panel p-4 shadow-xs"
    if title.present?
      div class: "flex items-start justify-between mb-3" do
        @title = h3(title.to_s, class: "text-xl font-extralight")
        div(class: "panel-actions") { action }  if action
      end
    end
    @contents = div(class: "text-sm")
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
