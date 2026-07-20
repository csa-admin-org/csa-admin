# frozen_string_literal: true

require "pathname"
require "yaml"

module Locales
  # Keep in sync with config/application.rb i18n.available_locales.
  LOCALES = %i[en fr de it nl].freeze

  # Keep in sync with Organization::BasketNaming::BASKET_I18N_SCOPES.
  BASKET_SCOPES = %w[basket bag share package cone crate].freeze

  # Keep in sync with Organization::ActivityFeature::ACTIVITY_I18N_SCOPES.
  ACTIVITY_SCOPES = %w[hour_work halfday_work day_work basket_preparation].freeze

  # lib/ → app root (not Dir.pwd — bin/locales must work from any CWD)
  APP_ROOT = Pathname.new(File.expand_path("..", __dir__)).freeze

  module_function

  def root
    if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
      Rails.root
    else
      APP_ROOT
    end
  end

  def deep_merge!(hash, other)
    other.each do |key, value|
      if hash[key].is_a?(Hash) && value.is_a?(Hash)
        deep_merge!(hash[key], value)
      else
        hash[key] = value
      end
    end
    hash
  end
end

require "locales/structure"
require "locales/catalog"
require "locales/checker"
