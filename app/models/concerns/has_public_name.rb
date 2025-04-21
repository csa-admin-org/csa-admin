# frozen_string_literal: true

module HasPublicName
  extend ActiveSupport::Concern

  included do
    attribute :admin_names, default: {}

    translated_attributes :name, required: true
    translated_attributes :public_name

    before_validation :set_names_and_public_names

    def display_name; name end

    def public_name
      self[:public_names][I18n.locale.to_s].presence || name
    end

    def public_name?
      self[:public_names][I18n.locale.to_s].present?
    end

    def public_names
      Current.org.languages.map { |locale|
        [ locale, self[:public_names][locale].presence || self[:names][locale] ]
      }.to_h
    end

    def admin_names
      Current.org.languages.map { |locale|
        if self[:public_names][locale].present?
          [ locale, self[:names][locale] ]
        else
          [ locale, nil ]
        end
      }.to_h
    end

    Organization::LANGUAGES.each do |locale|
      define_method("admin_name_#{locale}=") do |str|
        self[:admin_names][locale] = str&.strip
      end
    end
  end

  private

  def set_names_and_public_names
    return if self[:admin_names].empty?

    Current.org.languages.each do |locale|
      self[:names][locale] = self[:admin_names][locale].presence || self[:public_names][locale].presence
      if self[:public_names][locale].presence == self[:names][locale].presence
        self[:public_names][locale] = nil
      end
    end
    self[:admin_names] = nil
  end
end
