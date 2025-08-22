# frozen_string_literal: true

module ActiveAdmin::CounterHelper
  def counter_tag(title, count, type: nil)
    formatted_count =
      case type
      when :currency then cur(count, precision: 0)
      when :percentage then number_to_percentage(count, precision: 2)
      else; count
      end
    content_tag :span, class: "count" do
      concat content_tag(:span, count.zero? ? "–" : formatted_count, class: "count-value #{"count-zero" if count.zero?}")
      concat content_tag(:span, title, class: "count-title")
    end
  end
end
