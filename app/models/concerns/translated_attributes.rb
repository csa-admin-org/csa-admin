module TranslatedAttributes
  extend ActiveSupport::Concern

  class_methods do
    def translated_attributes(*attrs)
      attrs.each do |attr|
        column = attr.to_s.pluralize
        define_method(attr) { self[column][I18n.locale.to_s] }
        define_method("#{attr}=") { |str| self[column][I18n.locale.to_s] = str }

        scope "order_by_#{attr}", -> {
          order(Arel.sql("#{table_name}.#{column}->>'#{I18n.locale}'"))
        }
        scope "reorder_by_#{attr}", -> {
          reorder(Arel.sql("#{table_name}.#{column}->>'#{I18n.locale}'"))
        }
      end
    end
  end
end
