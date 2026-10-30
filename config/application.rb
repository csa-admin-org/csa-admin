# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CSAAdmin
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    # Tracking rails/rails main (8.2.0.alpha) until 8.2 ships. The CI group/step
    # polyfill in lib/rails_edge stays: upstream has groups, not --group/--step.
    config.load_defaults 8.2

    # 8.2 default. HTML compiles through Herb; every other format stays Erubi.
    # `bin/rails herb:check` is the compile gate. The ActiveAdmin navigation
    # override is what makes that check pass.
    config.action_view.erb_implementation = :herb

    # 8.2's :json refuses Marshal. Action Text stores attachment SGIDs in the
    # HTML body, signed with whatever serializer was current when the text was
    # saved. Those still include Marshal. New messages stay JSON.
    config.active_support.message_serializer = :json_allow_marshal

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # rails_edge: temporary ActiveSupport::ContinuousIntegration polyfill
    # query: Net::HTTP CLI under lib/query/{client,cli}.rb. Query already
    # lives in app/models/query/; autoloading both would clash.
    config.autoload_lib(ignore: %w[assets tasks rails_edge query])

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

    config.action_mailer.preview_paths << "#{Rails.root}/app/mailer_previews"

    # https://github.com/heartcombo/responders?tab=readme-ov-file#configuring-error-and-redirect-statuses
    config.responders.error_status = :unprocessable_entity
    config.responders.redirect_status = :see_other

    # Conflicting Client-IP / X-Forwarded-For is a malformed client request.
    # RemoteIp raises lazily from request.remote_ip (not in the middleware),
    # so ShowExceptions can map it. Keep ip_spoofing_check on.
    config.action_dispatch.rescue_responses.merge!(
      "ActionDispatch::RemoteIp::IpSpoofAttackError" => :bad_request
    )
  end
end
