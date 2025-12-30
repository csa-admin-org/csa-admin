# frozen_string_literal: true

class CheckBoxesInput < Formtastic::Inputs::CheckBoxesInput
  def to_html
    if collection.empty? && placeholder?
      input_wrapping do
        legend_html <<
        template.content_tag(:div,
          placeholder_content,
          class: "w-full rounded-lg border mt-1 border-dashed border-gray-300 px-6 py-6 text-center hover:border-gray-400 dark:border-gray-700 dark:hover:border-gray-600"
        )
      end
    else
      super
    end
  end

  def wrapper_html_options
    opts = super
    opts[:class] = [ opts[:class], "no-toggle-all" ].compact.join(" ") unless toggle_all?
    opts
  end

  def choices_wrapping_html_options
    {
      class: "choices",
      data: { controller: "check-boxes-toggle-all" }
    }
  end

  def extra_html_options(choice)
    choice_html_options = custom_choice_html_options(choice)
    input_html_options
      .merge(choice_html_options)
      .merge(data: {
        check_boxes_toggle_all_target: "input",
        action: "#{choice_html_options.dig(:data, :action)} check-boxes-toggle-all#updateToggle"
      }.merge(input_html_options[:data] || {}))
  end

  def legend_html
    return "".html_safe unless render_label?

    template.content_tag(:legend,
      template.content_tag(:div, legend_content, class: "checkbox-legend"),
      label_html_options.merge(class: "label"))
  end

  private

  def toggle_all?
    options.fetch(:toggle_all, true)
  end

  def placeholder?
    options.fetch(:placeholder, true) && target_class.present?
  end

  def legend_content
    template.content_tag(:label) do
      template.concat(toggle_checkbox)
      template.concat(template.content_tag(:span, label_text))
    end
  end

  def toggle_checkbox
    template.tag(:input, type: "checkbox", class: "size-4",
      data: {
        check_boxes_toggle_all_target: "toggle",
        form_checkbox_toggler_target: "input",
        action: "check-boxes-toggle-all#toggleAll"
      })
  end

  def placeholder_content
    content = template.content_tag(:span,
      I18n.t("active_admin.blank_slate.content", resource_name: resource_name),
      class: "block leading-6 text-gray-900 dark:text-gray-200"
    )
    content += template.link_to(I18n.t("active_admin.blank_slate.link"), new_path) if new_path
    content
  end

  def resource_name
    target_class&.model_name&.human(count: 2)&.downcase
  end

  def target_class
    options[:for] || reflection&.klass
  end

  def new_path
    return unless target_class

    route_name = "new_#{target_class.model_name.singular_route_key}_path"
    template.send(route_name) if template.respond_to?(route_name)
  rescue ActionController::UrlGenerationError
    nil
  end
end
