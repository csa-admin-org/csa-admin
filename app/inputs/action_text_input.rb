# frozen_string_literal: true

class ActionTextInput < Formtastic::Inputs::StringInput
  def to_html
    input_wrapping do
      label_html + action_text_editor_tag
    end
  end

  private

  def action_text_editor_tag
    options = input_html_options.dup
    value = options.delete(:value) { @object.public_send(@method) }
    options[:id] ||= @builder.field_id(@method)

    value = value.to_editor_html if value.respond_to?(:to_editor_html)
    value = ActionTextHtml.strip_underline(value)

    @template.rich_textarea_tag(@builder.field_name(@method), value, options)
  end
end
