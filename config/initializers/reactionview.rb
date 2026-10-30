# frozen_string_literal: true

ReActionView.configure do |config|
  # Client runtime is pinned with preload: false in config/importmap.rb.
  # Import "reactionview" from an entry point before turning this on.
  # Rails 8.2 already compiles HTML+ERB through Herb.
  # config.intercept_erb = true

  # Enable debug mode in development (adds debug attributes to HTML)
  config.debug_mode = Rails.env.development?

  # Path used for editor "open in editor" links (optional, defaults to Rails.root)
  # config.project_path = ENV.fetch("PROJECT_PATH", Rails.root.to_s)

  # Validation mode (:raise, :overlay, or :none) — defaults to :raise in test, :overlay otherwise
  # config.validation_mode = :overlay

  # How to handle templates that come from gems (:fallback, :skip, or :compile), defaults to :fallback
  # config.external_template_mode = :skip

  # Measure what a page does while it renders, and show it in the dev tools.
  # Follows development unless you say otherwise, and each measurement can be turned off.
  # config.instrumentation.enabled = Rails.env.development?
  # config.instrumentation.sql_queries = false
  # config.instrumentation.render_times = false
  # config.instrumentation.translations = false

  # Add visitors to the compile. Place them with `insert_before` and `insert_after`.
  # config.engine.visitors.use(Herb::Visitor.new)

  # Parser options for every compile, merged over the ones in .herb.yml
  # config.engine.parser_options = { strict_locals: true }
end
