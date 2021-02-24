class PrettyCheckBoxesInput < Formtastic::Inputs::CheckBoxesInput
  def choice_label(choice)
    template.content_tag(:span, nil, class: 'checkmark') <<
      template.content_tag(:span, super, class: 'label')
  end

  # Remove hint_html
  def input_wrapping(&block)
    template.content_tag(:li,
      [template.capture(&block), error_html].join("\n").html_safe,
      wrapper_html_options
    )
  end

  # Add hint_html after legend
  def to_html
    input_wrapping do
      choices_wrapping do
        legend_html <<
        hint_html <<
        hidden_field_for_all <<
        choices_group_wrapping do
          collection.map { |choice|
            choice_wrapping(choice_wrapping_html_options(choice)) do
              choice_html(choice)
            end
          }.join("\n").html_safe
        end
      end
    end
  end
end
