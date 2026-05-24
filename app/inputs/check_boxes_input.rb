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
    elsif grouped_collection.present?
      grouped_to_html
    else
      super
    end
  end

  def choices_wrapping_html_options
    opts = { class: "choices" }
    opts[:data] = { controller: "check-boxes-toggle-all" } if toggle_all?
    opts
  end

  def extra_html_options(choice)
    choice_html_options = custom_choice_html_options(choice)
    data = (input_html_options[:data] || {}).merge(choice_html_options[:data] || {})
    actions = [ data.delete(:action), data.delete("action") ].compact

    if toggle_all?
      data = data.merge(check_boxes_toggle_all_target: "input")
      actions << "check-boxes-toggle-all#updateToggle"
    end
    if grouped_collection.present?
      data = data.merge(check_boxes_group_toggle_target: "input")
      actions << "check-boxes-group-toggle#updateToggle"
    end

    input_html_options
      .merge(choice_html_options)
      .merge(data: data.merge(action: actions.uniq.join(" ")).compact)
  end

  def legend_html
    return "".html_safe unless render_label?

    template.content_tag(:legend,
      template.content_tag(:div, legend_content, class: "checkbox-legend"),
      label_html_options.merge(class: "label"))
  end

  private

  def grouped_to_html
    input_wrapping do
      choices_wrapping do
        legend_html <<
        hidden_field_for_all <<
        grouped_choices_html
      end
    end
  end

  def grouped_choices_html
    choices_by_value = collection.index_by { |choice| choice_value(choice).to_s }

    grouped_collection.filter_map { |group_label, group_ids|
      group_items = group_ids.filter_map { |id| choices_by_value[id.to_s] }
      group_section_html(group_label, group_items) if group_items.any?
    }.join("\n").html_safe
  end

  def group_section_html(group_label, group_items)
    template.content_tag(:div,
      group_header_html(group_label, group_items) +
      template.content_tag(:ol,
        group_items.map { |choice|
          choice_wrapping(choice_wrapping_html_options(choice)) do
            choice_html(choice)
          end
        }.join("\n").html_safe,
        class: "choices-group"
      ),
      class: "w-full not-last:mb-4",
      data: { controller: "check-boxes-group-toggle" }
    )
  end

  def group_header_html(group_label, group_items)
    template.content_tag(:div, class: "mb-1 flex items-center gap-2 text-sm font-semibold text-gray-600 dark:text-gray-400") do
      template.concat(group_toggle_checkbox)
      template.concat(template.content_tag(:span, group_label))
    end
  end

  def group_toggle_checkbox
    html_options = toggle_html_options(:group_toggle_html, "check-boxes-group-toggle#toggleAll")
    html_options[:data] = html_options[:data].merge(check_boxes_group_toggle_target: "toggle")
    template.tag(:input, html_options)
  end

  def toggle_all?
    options.fetch(:toggle_all, true)
  end

  def placeholder?
    options.fetch(:placeholder, true) && target_class.present?
  end

  def grouped_collection
    options[:grouped_collection]
  end

  def legend_content
    template.content_tag(:label) do
      template.concat(toggle_checkbox) if toggle_all?
      template.concat(template.content_tag(:span, label_text))
    end
  end

  def toggle_checkbox
    html_options = toggle_html_options(:toggle_html, "check-boxes-toggle-all#toggleAll")
    html_options[:data] = html_options[:data].merge(
      check_boxes_toggle_all_target: "toggle",
      form_checkbox_toggler_target: "input"
    )
    template.tag(:input, html_options)
  end

  def toggle_html_options(option_name, default_action)
    html_options = { type: "checkbox", class: "size-4" }.merge((options[option_name] || {}).deep_dup)
    data = (html_options[:data] || {}).dup
    data[:action] = [ default_action, data.delete(:action), data.delete("action") ].compact.uniq.join(" ")
    html_options.merge(data: data)
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
