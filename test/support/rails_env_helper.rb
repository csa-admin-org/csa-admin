# frozen_string_literal: true

module RailsEnvHelper
  def with_rails_env(name)
    previous_env = Rails.instance_variable_get(:@_env)
    Rails.instance_variable_set(:@_env, ActiveSupport::EnvironmentInquirer.new(name))
    yield
  ensure
    Rails.instance_variable_set(:@_env, previous_env)
  end
end
