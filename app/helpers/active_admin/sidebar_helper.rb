# frozen_string_literal: true

module ActiveAdmin::SidebarHelper
  def number_line(title, count, bold: true, border_top: false)
    content_tag :div, class: "cluster is-spread#{ " number-line-rule" if border_top }" do
      content_tag(:span, title) +
        content_tag(:span, count, class: "tabular-nums #{"font-bold" if bold}")
    end
  end
end
