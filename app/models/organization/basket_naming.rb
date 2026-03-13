# frozen_string_literal: true

module Organization::BasketNaming
  extend ActiveSupport::Concern

  BASKET_I18N_SCOPES = %w[basket bag share package cone]

  included do
    validate :validate_basket_i18n_scopes

    Organization.languages.each do |locale|
      define_method("basket_i18n_scope_#{locale}") { self[:basket_i18n_scopes][locale].presence }
      define_method("basket_i18n_scope_#{locale}=") do |value|
        self[:basket_i18n_scopes][locale] = value.presence
      end
    end
  end

  class_methods do
    def basket_i18n_scopes = BASKET_I18N_SCOPES
  end

  def basket_i18n_scopes=(value)
    case value
    when Hash
      super(value.select { |_, v| v.present? })
    when String
      super(languages.index_with { value }) if value.in?(BASKET_I18N_SCOPES)
    else
      super
    end
  end

  def basket_i18n_scope_for(locale)
    locale = locale.to_s
    locale = default_locale unless locale.in?(languages)
    scopes = basket_i18n_scopes
    scopes[locale] || scopes[default_locale] || BASKET_I18N_SCOPES.first
  end

  private

  def validate_basket_i18n_scopes
    scopes = basket_i18n_scopes
    unless scopes.is_a?(Hash)
      errors.add(:basket_i18n_scopes, :invalid)
      return
    end

    scopes.each do |lang, value|
      unless value.in?(BASKET_I18N_SCOPES)
        errors.add(:basket_i18n_scopes, :inclusion)
        break
      end
    end
  end
end
