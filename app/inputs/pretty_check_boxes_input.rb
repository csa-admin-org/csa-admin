class PrettyCheckBoxesInput < Formtastic::Inputs::CheckBoxesInput
  def choice_label(choice)
    template.content_tag(:span, nil, class: 'checkmark') <<
      template.content_tag(:span, super, class: 'label')
  end
end
