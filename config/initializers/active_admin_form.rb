# frozen_string_literal: true

# Override cancel_link to include arrow-left icon inline
module ActiveAdmin
  class FormBuilder < ::Formtastic::FormBuilder
    def cancel_link(url = { action: "index" }, html_options = {}, li_attrs = {})
      li_attrs[:class] ||= "action cancel"
      html_options[:class] ||= "cancel-link"
      li_content = template.link_to(url, **html_options) do
        template.icon("arrow-left", class: "size-5 -ms-1 me-2") +
          I18n.t("active_admin.cancel")
      end
      template.content_tag(:li, li_content, li_attrs)
    end

    private

    # Use <button> instead of <input type="submit"> so we can include icon HTML
    def default_action_type(method, options = {})
      case method
      when :submit then :button
      when :reset  then :button
      when :cancel then :link
      else method
      end
    end
  end
end

# Override ButtonAction to render submit buttons with a check icon.
# Pass `icon: "send-horizontal"` (or any icon name) to f.action to customize.
Formtastic::Actions::ButtonAction.class_eval do
  def to_html
    icon_name = options[:icon] || "check"
    wrapper do
      template.form_submit_tag(text, icon: icon_name, icon_class: options[:icon_class], **button_html)
    end
  end
end
