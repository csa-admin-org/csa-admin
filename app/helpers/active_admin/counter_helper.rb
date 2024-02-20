module ActiveAdmin::CounterHelper
  def counter_tag(title, count)
    content_tag(:span, class: ("zero" if count.zero?)) do
      concat content_tag(:span, count.zero? ? "–" : count, class: "count")
      concat content_tag(:span, title)
    end
  end
end
