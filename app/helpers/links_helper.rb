# frozen_string_literal: true

module LinksHelper
  def icon_file_link(type, url, size: 6, title: nil, **options)
    title ||= type.upcase
    content_tag :span do
      link_to(url, title: title, **options) do
        icon "file-#{type}", class: "h-#{size} w-#{size}"
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
