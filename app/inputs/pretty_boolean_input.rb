class PrettyBooleanInput < Formtastic::Inputs::BooleanInput
  def label_text
    template.content_tag(:span, nil, class: 'checkmark') <<
      template.content_tag(:span, super, class: 'label')
  end
end
