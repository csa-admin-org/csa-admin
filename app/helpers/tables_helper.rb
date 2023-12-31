module TablesHelper
  def display_with_external_url(text, url)
    txt = text
    if url.present?
      txt += link_to(url, target: "_blank") do
        inline_svg_tag("admin/external-link.svg", size: "16")
      end
    end
    content_tag(:span, txt.html_safe, class: "url")
  end
end
