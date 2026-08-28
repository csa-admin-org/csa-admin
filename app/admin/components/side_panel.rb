# frozen_string_literal: true

class SidePanel < ActiveAdmin::Component
  builder_method :side_panel

  def build(title, *args)
    args = args.extract_options!
    action = args.delete(:action) if args.key?(:action)
    add_class args.delete(:class) if args.key?(:class)
    super(*args)
    add_class "panel admin-side-panel"
    if title.present?
      div class: "admin-side-panel-header" do
        @title = h3(title.to_s, class: "admin-side-panel-title")
        div(class: "panel-actions") { action }  if action
      end
    end
    @contents = div(class: "admin-side-panel-body")
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
