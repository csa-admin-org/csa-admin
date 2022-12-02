class CustomRangeInput < Formtastic::Inputs::RangeInput
  def to_html
    input_wrapping do
      label_html <<
      builder.range_field("#{method}_foo".to_sym, range_html_options) <<
      builder.text_field(method, input_html_options)
    end
  end

  private

  def range_html_options
    input_html_options.merge(options[:range_html] || {})
  end
end
