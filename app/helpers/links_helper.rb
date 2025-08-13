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
        icon "ellipsis-horizontal", class: "size-6"
      end
    end
  end

  def action_link(name, url, icon: nil, **options)
    link_to url, class: "h-9 action-item-button #{options.delete(:class)}", **options do
      txt = name.to_s.html_safe
      txt.prepend(icon(icon, class: "size-5 #{"-ms-1 me-2" if name}")) if icon.present?
      txt
    end
  end

  def action_button(name, url, icon: nil, **options)
    button_to url, class: "h-9 action-item-button #{options.delete(:class)}", form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } }, **options do
      txt = name.to_s.html_safe
      txt.prepend(icon(icon, class: "text-white size-5 #{"-ms-2 me-2" if name}")) if icon.present?
      txt
    end
  end
end
