require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
require 'rails'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'active_job/railtie'
require 'action_cable/engine'
require 'action_text/engine'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ACPAdmin
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Zurich'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.available_locales = %w[en fr de]
    config.i18n.default_locale = :fr
    config.i18n.fallbacks = true

    # :time must not be included here because of the tod gem
    # https://github.com/JackC/tod#activemodel-serializable-attribute-support
    config.active_record.time_zone_aware_types = [:datetime]

    # The project specific .irbrc is automatically loaded on Heroku,
    # we want to load it locally as well.
    console do
      load File.expand_path('../.irbrc', __dir__)
    end

    config.active_job.queue_adapter = :sucker_punch
    config.action_mailer.preview_path = "#{Rails.root}/app/mailer_previews"
  end
end
