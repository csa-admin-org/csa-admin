# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CSAAdmin
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

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

    config.time_zone = "Europe/Zurich"

    config.i18n.available_locales = %w[en fr de it nl]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = true

    # :time must not be included here because of the tod gem
    # https://github.com/JackC/tod#activemodel-serializable-attribute-support
    config.active_record.time_zone_aware_types = [ :datetime ]

    config.action_mailer.preview_paths = [ "#{Rails.root}/app/mailer_previews" ]

    # https://github.com/heartcombo/responders?tab=readme-ov-file#configuring-error-and-redirect-statuses
    config.responders.error_status = :unprocessable_entity
    config.responders.redirect_status = :see_other
  end
end
