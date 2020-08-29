class PrettyRadioInput < Formtastic::Inputs::RadioInput

  def legend_html
    txt = super
    if text = options[:text]
      txt += template.content_tag(:p, text, class: 'legend-text')
    end
    txt
  end

  def choice_label(choice)
    template.content_tag(:span, nil, class: 'checkmark') <<
      template.content_tag(:span, super, class: 'label')
  end
end
