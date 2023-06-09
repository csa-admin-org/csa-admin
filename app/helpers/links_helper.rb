module LinksHelper
  def icon_link(icon, title, url, size: 24, **options)
    content_tag :span do
      link_to(url, title: title, **options) do
        inline_svg_tag("admin/#{icon}.svg", size: size.to_s)
      end
    end
  end
end
