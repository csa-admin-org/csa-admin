# frozen_string_literal: true

# Ensure that the IceCube locales are loaded before our own to avoid conflicts
# https://github.com/ice-cube-ruby/ice_cube/pull/546
require "ice_cube"

I18n.backend = I18n::Backend::SideBySide.new

ISO3166.configure do |config|
  config.locales = I18n.available_locales
end
