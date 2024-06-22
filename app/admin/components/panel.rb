# frozen_string_literal: true

class Panel < ActiveAdmin::Component
  builder_method :panel

  def build(title, *args)
    args = args.extract_options!
    action = args.delete(:action) if args.key?(:action)
    count = args.delete(:count) if args.key?(:count)
    super(args)
    add_class "panel"
    div class: "panel-title justify-between" do
      div class: "flex items-center gap-2" do
        @title = h3(title.to_s, class: "")
        span(class: "panel-title-count") { count } if count
      end
      div(class: "panel-actions") { action } if action
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

  # Override children? to only report children when the panel's
  # contents have been added to. This ensures that the panel
  # correctly appends string values, etc.
  def children?
    @contents.children?
  end
end
