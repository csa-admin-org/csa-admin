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
    options[:class] = [ options[:class], "trix-content" ].compact.join(" ")
    value = options.delete(:value) { @object.public_send(@method) }
    options[:id] ||= @builder.field_id(@method)
    options[:input] ||= ActionView::RecordIdentifier.dom_id(@object, [ options[:id], :trix_input ].compact.join("_")) if @object

    @template.rich_textarea_tag(@builder.field_name(@method), value, options)
  end
end
