module HalfdayNaming
  extend ActiveSupport::Concern

  class Name < ActiveModel::Name
    def i18n_key
      if Apartment::Tenant.current != 'public'
        "#{super}/#{Current.acp.halfday_i18n_scope}".to_sym
      else
        super
      end
    end
  end

  class_methods do
    def model_name
      @_model_name ||= begin
        namespace = parents.find do |n|
          n.respond_to?(:use_relative_model_naming?) &&
            n.use_relative_model_naming?
        end
        Name.new(self, namespace)
      end
    end
  end
end
