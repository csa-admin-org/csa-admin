# frozen_string_literal: true

require "test_helper"
require "security"

class Security::ToolsTest < ActiveSupport::TestCase
  setup do
    @previous_github_actions = ENV["GITHUB_ACTIONS"]
    ENV.delete("GITHUB_ACTIONS")
  end

  teardown do
    if @previous_github_actions
      ENV["GITHUB_ACTIONS"] = @previous_github_actions
    else
      ENV.delete("GITHUB_ACTIONS")
    end
  end

  test "default commands match local CI flags" do
    commands = commands_for

    assert_equal %w[bin/bundler-audit check --update], commands[:bundler_audit]
    assert_equal %w[bin/importmap audit], commands[:importmap]
    assert_equal %w[bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error], commands[:brakeman]
    assert_equal %w[bin/aube audit], commands[:aube]
  end

  test "brakeman writes SARIF under GitHub Actions" do
    ENV["GITHUB_ACTIONS"] = "true"

    commands = commands_for

    assert_equal %w[bin/brakeman -f sarif -o results.sarif], commands[:brakeman]
  end

  private

  def commands_for
    Security::Tools.all.to_h { |tool|
      instance = tool.new
      [ instance.name, instance.command ]
    }
  end
end
