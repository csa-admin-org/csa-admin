# frozen_string_literal: true

module HasPublicName
  extend ActiveSupport::Concern

  included do
    translated_attributes :name, required: true
    translated_attributes :public_name

    def display_name; name end

    def public_name
      self[:public_names][I18n.locale.to_s].presence || name
    end
  end
end
