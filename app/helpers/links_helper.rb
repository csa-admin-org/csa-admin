module LinksHelper
  def icon_link(icon, title, url, size: 22, **options)
    content_tag :span do
      link_to(url, title: title, **options) do
        inline_svg_tag("admin/#{icon}.svg", size: size.to_s)
      end
    end
  end

  def show_more_link(url)
    content_tag :div, class: "mt-2 flex justify-center" do
      link_to url, title: t(".show_more") do
        icon "ellipsis-horizontal", class: "h-6 w-6"
      end
    end
  end
end
