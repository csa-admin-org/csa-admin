class ActionTextInput < Formtastic::Inputs::StringInput
  def to_html
    input_wrapping do
      input_html_options[:class] << " trix-content"
      editor_tag = builder.rich_text_area(method, input_html_options)
      label_html + editor_tag
    end
  end
end
