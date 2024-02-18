require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ACPAdmin
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.time_zone = "Zurich"

    config.i18n.available_locales = %w[en fr de it]
    config.i18n.default_locale = :fr
    config.i18n.fallbacks = true

    # :time must not be included here because of the tod gem
    # https://github.com/JackC/tod#activemodel-serializable-attribute-support
    config.active_record.time_zone_aware_types = [ :datetime ]

    # The project specific .irbrc is automatically loaded on Heroku,
    # we want to load it locally as well.
    console do
      load File.expand_path("../.irbrc", __dir__)
    end

    config.action_mailer.preview_paths = [ "#{Rails.root}/app/mailer_previews" ]
  end
end
