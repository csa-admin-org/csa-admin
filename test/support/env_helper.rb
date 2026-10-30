# frozen_string_literal: true

module EnvHelper
  def with_env(env)
    old_values = env.keys.index_with { |key| ENV[key] }
    assign_env(env)
    Rails.app.creds.reload
    yield
  ensure
    assign_env(old_values)
    Rails.app.creds.reload
  end

  def assign_env(env)
    env.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
