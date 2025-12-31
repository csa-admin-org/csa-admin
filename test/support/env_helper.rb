# frozen_string_literal: true

module EnvHelper
  def with_env(env)
    old_values = env.keys.index_with { |key| ENV[key] }
    env.each { |key, value| ENV[key] = value }
    yield
  ensure
    old_values.each { |key, value| ENV[key] = value }
  end
end
