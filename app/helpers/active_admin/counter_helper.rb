module ActiveAdmin::CounterHelper
  def counter_tag(title, count)
    content_tag :span, class: "count" do
      concat content_tag(:span, count.zero? ? "–" : count, class: "count-value #{"count-zero" if count.zero?}")
      concat content_tag(:span, title, class: "count-title")
    end
  end
end
