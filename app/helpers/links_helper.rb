# frozen_string_literal: true

module LinksHelper
  def icon_file_link(type, url, size: 6, title: nil, **options)
    title ||= type.upcase
    content_tag :span do
      link_to(url, title: title, class: "inline-flex flex-col items-center no-underline", **options) do
        icon("file-down", class: "h-#{size} w-#{size}") +
          content_tag(:span, type.upcase, class: "text-[0.575rem] mt-px font-bold leading-none")
      end
    end
  end

  def icon_file_links(*links)
    content_tag(:div, class: "flex items-center gap-2") do
      safe_join(links)
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
    _submit_button(name, url,
      icon: icon, icon_class: "text-white size-5 #{"-ms-2 me-2" if name}",
      btn_class: "h-9 action-item-button #{options.delete(:class)}",
      disabled: disabled, disabled_tooltip: disabled_tooltip,
      **options)
  end

  def panel_button(name, url = nil, icon: nil, disabled: false, disabled_tooltip: nil, **options, &block)
    _submit_button(name, url,
      icon: icon, icon_class: "size-4 me-2",
      btn_class: options.delete(:class) || "btn btn-sm",
      disabled: disabled, disabled_tooltip: disabled_tooltip,
      **options, &block)
  end

  private

  def _submit_button(name, url, btn_class:, icon: nil, icon_class: nil,
                     disabled: false, disabled_tooltip: nil, **options, &block)
    if disabled
      _disabled_button(name, btn_class: btn_class, icon: icon, icon_class: icon_class, tooltip: disabled_tooltip)
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
          txt.prepend(icon(icon, class: icon_class)) if icon.present?
          txt
        end
      end
    end
  end

  def _disabled_button(name, btn_class:, icon: nil, icon_class: nil, tooltip: nil)
    tooltip_id = "tooltip-#{SecureRandom.hex(4)}"
    icon_class = icon_class&.gsub(/\btext-white\b/, "")&.squish

    content_tag(:button,
      class: "#{btn_class} cursor-not-allowed".squish,
      disabled: true,
      data: { "tooltip-target" => tooltip_id, "tooltip-placement" => "bottom" }
    ) do
      txt = name.to_s.html_safe
      txt.prepend(icon(icon, class: icon_class)) if icon.present?
      txt
    end +
    tooltip_element(tooltip_id, tooltip)
  end
end
