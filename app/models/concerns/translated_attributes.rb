# frozen_string_literal: true

module TranslatedAttributes
  extend ActiveSupport::Concern

  included do
    class_attribute :ransackable_translated_scopes, default: []
  end

  class_methods do
    def translated_attributes(*attrs, required: false)
      attrs.each do |attr|
        column = attr.to_s.pluralize
        define_method(attr) do |locale = I18n.locale|
          send("#{attr}_with_fallback", locale)
        end
        define_method("#{attr}_with_fallback") do |locale = I18n.locale|
          self[column][locale.to_s].presence&.html_safe
            || self[column][Current.org.default_locale.to_s].presence&.html_safe
        end
        define_method("#{attr}_without_fallback") do |locale = I18n.locale|
          self[column][locale.to_s].presence&.html_safe
        end
        define_method("#{attr}?") do |locale = I18n.locale|
          send(attr, locale).present?
        end
        define_method("#{attr}=") do |str|
          Organization.languages.each do |locale|
            send("#{attr}_#{locale}=", str.presence&.strip)
          end
        end
        Organization.languages.each do |locale|
          define_method("#{attr}_#{locale}") { self[column][locale].presence }
          define_method("#{attr}_#{locale}=") do |str|
            self[column][locale] = str.presence&.strip
          end
        end

        scope "order_by_#{attr}", ->(dir = "ASC") {
          order(Arel.sql("unaccent(text_lower(json_extract(#{table_name}.#{column}, '$.#{I18n.locale}'))) #{dir}"))
        }
        scope "reorder_by_#{attr}", ->(dir = "ASC") {
          unscope(:order).send("order_by_#{attr}", dir)
        }
        scope "#{attr}_eq", ->(str) {
          where("json_extract(#{table_name}.#{column}, '$.#{I18n.locale}') = ?", str)
        }
        self.ransackable_translated_scopes << "#{attr}_eq"
        scope "#{attr}_cont", ->(str) {
          where("lower(json_extract(#{table_name}.#{column}, '$.#{I18n.locale}')) LIKE ?", "%#{str.downcase}%")
        }
        self.ransackable_translated_scopes << "#{attr}_cont"

        if required
          validate_options = required.is_a?(Hash) ? required : {}
          Organization.languages.each do |locale|
            validates "#{attr}_#{locale}".to_sym, presence: true, **validate_options, if: -> {
              locale.in?(Current.org.languages)
            }
          end
        end
      end

      define_singleton_method(:ransackable_scopes) do |_auth_object = nil|
        super(_auth_object) + self.ransackable_translated_scopes
      end
    end
  end
end
