# frozen_string_literal: true

module TablesHelper
  def display_with_external_url(text, url)
    txt = text
    if url.present?
      txt += link_to(url, target: "_blank") do
        icon("external-link", class: "icon-4")
      end
    end
    content_tag(:span, txt.html_safe, class: "cluster")
  end
end
