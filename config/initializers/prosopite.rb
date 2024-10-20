# frozen_string_literal: true

# https://github.com/charkost/prosopite?tab=readme-ov-file#development-environment-usage
Rails.application.configure do
  if Rails.env.development?
    config.after_initialize do
      Prosopite.rails_logger = true
      Prosopite.raise = false
      Prosopite.min_n_queries = 3
    end
  end
end
