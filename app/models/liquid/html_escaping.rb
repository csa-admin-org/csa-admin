# frozen_string_literal: true

module Liquid
  module HtmlEscaping
    def [](method_or_key)
      escape_liquid_value(super)
    end

    private

    def escape_liquid_value(value)
      case value
      when String
        ERB::Util.html_escape(value)
      when Array
        value.map { |item| escape_liquid_value(item) }
      when Hash
        value.to_h { |key, item| [ key, escape_liquid_value(item) ] }
      else
        value
      end
    end
  end
end
