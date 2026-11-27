# frozen_string_literal: true

require "test_helper"
require "erb"
require "yaml"

class DatabaseYmlTest < ActiveSupport::TestCase
  test "development TENANT filter still limits to configured tenants" do
    configured = development_tenant_names
    config = render_database_yml(env: "development", tenant: "#{configured.first},retired")

    assert_equal [ configured.first ], config.fetch("development").keys
  end

  test "development TENANT filter keeps configured tenants when the name is unknown" do
    configured = development_tenant_names
    config = render_database_yml(env: "development", tenant: "retired")
    dev = config.fetch("development")

    assert_equal configured, dev.keys
    assert_not_includes dev.keys, "retired"
  end

  test "test environment ignores TENANT when building database config" do
    config = render_database_yml(env: "test", tenant: "retired")

    assert_equal %w[acme beta], config.fetch("test").keys
  end

  private

  def development_tenant_names
    YAML.load_file(Rails.root.join("config/tenant.yml"), aliases: true).fetch("development").keys
  end

  def render_database_yml(env:, tenant:)
    source = Rails.root.join("config/database.yml").read

    yaml = with_rails_env(env) do
      with_env("TENANT" => tenant) do
        ERB.new(source).result
      end
    end

    YAML.safe_load(yaml, aliases: true)
  end
end
