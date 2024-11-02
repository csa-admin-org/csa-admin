# frozen_string_literal: true

module TranslatedAttributes
  extend ActiveSupport::Concern

  class_methods do
    def translated_attributes(*attrs, required: false)
      attrs.each do |attr|
        column = attr.to_s.pluralize
        define_method(attr) do |locale = I18n.locale|
          send("#{attr}_with_fallback", locale)
        end
        define_method("#{attr}_with_fallback") do |locale = I18n.locale|
          self[column][locale.to_s].presence ||
            self[column][Current.org.default_locale.to_s].presence
        end
        define_method("#{attr}_without_fallback") do |locale = I18n.locale|
          self[column][locale.to_s].presence
        end
        define_method("#{attr}?") do |locale = I18n.locale|
          send(attr, locale).present?
        end
        define_method("#{attr}=") do |str|
          Organization::LANGUAGES.each do |locale|
            send("#{attr}_#{locale}=", str)
          end
        end
        Organization::LANGUAGES.each do |locale|
          define_method("#{attr}_#{locale}") { self[column][locale].presence }
          define_method("#{attr}_#{locale}=") do |str|
            if str.present?
              self[column][locale] = str
            else
              self[column][locale] = nil
            end
          end
        end

        scope "order_by_#{attr}", -> {
          order(Arel.sql("json_extract(#{table_name}.#{column}, '$.#{I18n.locale}')"))
        }
        scope "reorder_by_#{attr}", -> {
          reorder(Arel.sql("json_extract(#{table_name}.#{column}, '$.#{I18n.locale}')"))
        }
        scope "#{attr}_eq", ->(str) {
          where("json_extract(#{table_name}.#{column}, '$.#{I18n.locale}') = ?", str)
        }
        scope "#{attr}_cont", ->(str) {
          where("lower(json_extract(#{table_name}.#{column}, '$.#{I18n.locale}')) LIKE ?", "%#{str.downcase}%")
        }

        if required
          Organization::LANGUAGES.each do |locale|
            validates "#{attr}_#{locale}".to_sym, presence: true, if: -> {
              locale.in?(Current.org.languages)
            }
          end
        end
      end

      define_singleton_method(:ransackable_scopes) do |_auth_object = nil|
        super(_auth_object) + attrs.flat_map { |attr| [ "#{attr}_eq", "#{attr}_cont" ] }
      end
    end
  end
end
