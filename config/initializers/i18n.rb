I18n.backend = I18n::Backend::SideBySide.new

ISO3166.configure do |config|
  config.locales = I18n.available_locales
end
