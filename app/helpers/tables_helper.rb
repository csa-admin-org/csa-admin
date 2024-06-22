# frozen_string_literal: true

module TablesHelper
  def display_with_external_url(text, url)
    txt = text
    if url.present?
      txt += link_to(url, target: "_blank") do
        icon("arrow-top-right-on-square", class: "h-4 w-4 ml-1")
      end
    end
    content_tag(:span, txt.html_safe, class: "flex items-center")
  end
end
