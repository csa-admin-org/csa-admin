# frozen_string_literal: true

ReActionView.configure do |config|
  # Intercept .html.erb templates and process them with `Herb::Engine` for enhanced features
  # config.intercept_erb = true

  # Enable debug mode in development (adds debug attributes to HTML)
  config.debug_mode = Rails.env.development?

  # Add visitors to the compile. Place them with `insert_before` and `insert_after`.
  # config.engine.visitors.use(Herb::Visitor.new)

  # Parser options for every compile, merged over the ones in .herb.yml
  # config.engine.parser_options = { strict_locals: true }
end
