# frozen_string_literal: true

class Panel < ActiveAdmin::Component
  builder_method :panel

  def build(title, *args)
    args = args.extract_options!
    action = args.delete(:action) if args.key?(:action)
    state = args.delete(:state) if args.key?(:state)
    count = args.delete(:count) if args.key?(:count)
    count_label = args.delete(:count_label) if args.key?(:count_label)
    icon_name = args.delete(:icon) if args.key?(:icon)
    super(args)
    add_class "panel"
    if title
      div class: "panel-title" do
        div class: "panel-title-heading" do
          if icon_name
            span(class: "panel-title-icon") { icon(icon_name, class: "icon-5") }
          end
          @title = h3(title.to_s, class: "")
          panel_title_counts(count, count_label)
          status_tag(state) if state
        end
        div(class: "panel-actions") { action } if action
      end
    end
    @contents = div(class: "panel-body")
  end

  def panel_title_counts(count, label)
    return unless count

    if count.is_a?(Array)
      span(class: "panel-title-count") { count.first }
      if label
        span(class: "panel-title-count-separator") { "/" }
        span(class: "panel-title-count-label") { label }
      end
      span(class: "panel-title-count") { count.last }
    else
      span(class: "panel-title-count") { count }
    end
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
