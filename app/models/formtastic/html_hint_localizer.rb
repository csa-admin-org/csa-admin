# frozen_string_literal: true

module Formtastic
  class HtmlHintLocalizer < ::Formtastic::Localizer
    def localize(key, value, type, options = {})
      result = super
      return result if result

      if type == :hint && !value.is_a?(::String) && (value.nil? ? i18n_lookups_by_default : (value != false))
        attribute_name = (value.is_a?(::Symbol) ? value : key).to_s
        html_attribute = attribute_name.end_with?("_html") ? attribute_name : "#{attribute_name}_html"

        model_name, nested_model_name = normalize_model_name(builder.model_name.underscore)
        action_name = builder.template.params[:action].to_s rescue ""

        defaults = Formtastic::I18n::SCOPES.reject { |scope|
          nested_model_name.nil? && scope.match(/nested_model/)
        }.collect { |scope|
          i18n_path = scope.dup
          i18n_path.gsub!("%{action}", action_name)
          i18n_path.gsub!("%{model}", model_name)
          i18n_path.gsub!("%{nested_model}", nested_model_name) unless nested_model_name.nil?
          i18n_path.gsub!("%{attribute}", html_attribute)
          i18n_path.tr!("..", ".")
          i18n_path.to_sym
        }

        defaults << ""
        defaults.uniq!
        default_key = defaults.shift
        i18n_value = Formtastic::I18n.t(default_key, default: defaults, scope: :hints)
        i18n_value = nil unless i18n_value.is_a?(::String) && i18n_value.present?
        i18n_value&.html_safe
      end
    end
  end
end
