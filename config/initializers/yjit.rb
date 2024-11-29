# frozen_string_literal: true

# TODO: Remove when released in Rails 8.1
# https://github.com/rails/rails/pull/53746
Rails.application.configure do
  config.yjit = !Rails.env.local?
end
