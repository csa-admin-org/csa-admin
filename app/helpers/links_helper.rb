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

  def action_button(name, url = nil, icon: nil, disabled: false, disabled_tooltip: nil, **options)
    if disabled
      disabled_action_button(name, tooltip: disabled_tooltip, icon_name: icon)
    else
      button_to url, class: "h-9 action-item-button #{options.delete(:class)}", form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } }, **options do
        txt = name.to_s.html_safe
        txt.prepend(icon(icon, class: "text-white size-5 #{"-ms-2 me-2" if name}")) if icon.present?
        txt
      end
    end
  end

  def panel_button(name, url = nil, icon: nil, disabled: false, disabled_tooltip: nil, **options, &block)
    btn_class = options.delete(:class) || "btn btn-sm"

    if disabled
      disabled_button(name, tooltip: disabled_tooltip, icon_name: icon, btn_class: btn_class)
    else
      form_options = options.delete(:form) || {}
      form_options[:data] ||= {}
      form_options[:data][:controller] ||= "disable"
      form_options[:data][:disable_with_value] ||= t("formtastic.processing")

      button_to url, class: btn_class, form: form_options, **options do
        if block
          yield
        else
          txt = name.to_s.html_safe
          txt.prepend(icon(icon, class: "size-4 me-2")) if icon.present?
          txt
        end
      end
    end
  end
end
