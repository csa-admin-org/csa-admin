# frozen_string_literal: true

class Panel < ActiveAdmin::Component
  builder_method :panel

  def build(title, *args)
    args = args.extract_options!
    action = args.delete(:action) if args.key?(:action)
    state = args.delete(:state) if args.key?(:state)
    count = args.delete(:count) if args.key?(:count)
    icon_name = args.delete(:icon) if args.key?(:icon)
    super(args)
    add_class "panel"
    if title
      div class: "panel-title justify-between" do
        div class: "flex items-center gap-2" do
          if icon_name
            span(class: "panel-title-icon") { icon(icon_name, class: "size-5") }
          end
          @title = h3(title.to_s, class: "")
          span(class: "panel-title-count") { count } if count
          status_tag(state) if state
        end
        div(class: "panel-actions") { action } if action
      end
    end
    @contents = div(class: "panel-body")
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
