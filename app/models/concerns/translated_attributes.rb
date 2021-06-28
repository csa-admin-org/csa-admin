module TranslatedAttributes
  extend ActiveSupport::Concern

  class_methods do
    def translated_attributes(*attrs)
      attrs.each do |attr|
        column = attr.to_s.pluralize
        define_method(attr) { |locale = I18n.locale| self[column][locale.to_s].presence }
        define_method("#{attr}=") { |str| self[column][I18n.locale.to_s] = str }
        ACP::LANGUAGES.each do |locale|
          define_method("#{attr}_#{locale}") do
            self[column][locale].presence
          end
          define_method("#{attr}_#{locale}=") do |str|
            self[column][locale] = str
          end
        end

        scope "order_by_#{attr}", -> {
          order(Arel.sql("#{table_name}.#{column}->>'#{I18n.locale}'"))
        }
        scope "reorder_by_#{attr}", -> {
          reorder(Arel.sql("#{table_name}.#{column}->>'#{I18n.locale}'"))
        }
        scope "#{attr}_eq", ->(str) {
          where("#{table_name}.#{column}->>'#{I18n.locale}' = ?", str)
        }
        scope "#{attr}_contains", ->(str) {
          where("#{table_name}.#{column}->>'#{I18n.locale}' ILIKE ?", "%#{str}%")
        }
      end

      define_singleton_method(:ransackable_scopes) do |_auth_object = nil|
        super(_auth_object) + attrs.map { |attr| "#{attr}_eq" }
      end
    end
  end
end
