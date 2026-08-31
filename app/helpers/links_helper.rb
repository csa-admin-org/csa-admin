# frozen_string_literal: true

module LinksHelper
  def icon_file_link(type, url, size: 6, title: nil, **options)
    title ||= type.upcase
    content_tag :span, class: "icon-file-link" do
      link_to(url, title: title, class: "icon-file-link-anchor", **options) do
        icon("file-down", class: "icon-file-link-icon is-#{size}") +
          content_tag(:span, type.upcase, class: "icon-file-link-label")
      end
    end
  end

  def icon_file_links(*links)
    content_tag(:div, class: "icon-file-links") do
      safe_join(links)
    end
  end

  def show_more_link(url)
    content_tag :div, class: "table-more" do
      link_to url, title: t(".show_more") do
        icon "ellipsis", class: "icon-6"
      end
    end
  end

  def form_submit_tag(label, icon: "check", icon_class: nil, **options)
    icon_name = icon
    icon_class ||= "icon-5"
    options[:type] ||= :submit
    content_tag(:button, **options) do
      icon(icon_name, class: icon_class) + label
    end
  end

  def action_link(name, url, icon: nil, **options)
    link_to url, class: "action-item-button #{options.delete(:class)}", **options do
      txt = name.to_s.html_safe
      txt.prepend(icon(icon, class: "icon-5")) if icon.present?
      txt
    end
  end

  def action_button(name, url = nil, icon: nil, disabled: false, disabled_tooltip: nil, **options)
    _submit_button(name, url,
      icon: icon, icon_class: "icon-5",
      btn_class: "action-item-button #{options.delete(:class)}",
      disabled: disabled, disabled_tooltip: disabled_tooltip,
      **options)
  end

  def panel_button(name, url = nil, icon: nil, disabled: false, disabled_tooltip: nil, **options, &block)
    _submit_button(name, url,
      icon: icon, icon_class: "icon-4",
      btn_class: options.delete(:class) || "btn btn-sm",
      disabled: disabled, disabled_tooltip: disabled_tooltip,
      **options, &block)
  end

  def reactivate_email_suppression_button(suppression, btn_class: "btn btn-sm", as: :button)
    content = icon("circle-check-big", class: "icon-4") +
      t("helpers.email_suppressions.destroy")
    confirm = t("helpers.email_suppressions.destroy_confirm")

    if as == :link
      link_to email_suppression_path(suppression),
        class: btn_class,
        data: { turbo_method: :delete, turbo_confirm: confirm } do
          content
        end
    else
      button_to email_suppression_path(suppression),
        method: :delete,
        class: btn_class,
        data: { confirm: confirm } do
          content
        end
    end
  end

  private

  def _submit_button(name, url, btn_class:, icon: nil, icon_class: nil,
                     disabled: false, disabled_tooltip: nil, **options, &block)
    if disabled
      _disabled_button(name, btn_class: btn_class, icon: icon, icon_class: icon_class,
        tooltip: disabled_tooltip, **options.slice(:title, :aria))
    else
      form_options = options.delete(:form) || {}
      form_options[:data] ||= {}
      form_options[:data][:controller] ||= "disable"
      form_options[:data][:disable_with_value] ||= t("formtastic.processing")
      ensure_delete_confirmation!(options)

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

  def ensure_delete_confirmation!(options)
    return unless options[:method].to_s == "delete"

    data = options[:data] ||= {}
    data[:confirm] = t("active_admin.delete_confirmation") unless data.key?(:confirm) || data.key?("confirm")
  end

  def _disabled_button(name, btn_class:, icon: nil, icon_class: nil, tooltip: nil, **options)
    icon_class = icon_class&.gsub(/\btext-white\b/, "")&.squish

    content_tag(:span,
      class: "cluster",
      tabindex: 0,
      data: {
        controller: "tooltip",
        "tooltip-target" => "trigger",
        "tooltip-placement-value" => "bottom",
        action: "mouseenter->tooltip#show mouseleave->tooltip#hide focus->tooltip#show blur->tooltip#hide"
      },
      **options.slice(:title, :aria)
    ) do
      content_tag(:button,
        class: "#{btn_class} is-disabled".squish,
        disabled: true,
        **options
      ) do
        txt = name.to_s.html_safe
        txt.prepend(icon(icon, class: icon_class)) if icon.present?
        txt
      end +
      tooltip_element(tooltip)
    end
  end
end
