module LinksHelper
  def link_to_with_icon(icon, text, url, options = {})
    text_with_icon = content_tag :span, class: 'link-with-icon' do
      inline_svg_tag("admin/#{icon}.svg", size: '18') +
        content_tag(:span, text)
    end
    link_to(text_with_icon, url, options)
  end
end
