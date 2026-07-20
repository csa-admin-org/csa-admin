# frozen_string_literal: true

require "test_helper"
require "security"

class Security::ToolsTest < ActiveSupport::TestCase
  test "default commands match local CI flags" do
    commands = commands_for

    assert_equal "bin/bundler-audit check --update", commands[:bundler_audit]
    assert_equal "bin/importmap audit", commands[:importmap]
    assert_equal "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error", commands[:brakeman]
    assert_equal "aube audit", commands[:aube]
  end

  test "brakeman writes SARIF under GitHub Actions" do
    previous = ENV["GITHUB_ACTIONS"]
    ENV["GITHUB_ACTIONS"] = "true"

    commands = commands_for

    assert_equal "bin/brakeman -f sarif -o results.sarif", commands[:brakeman]
  ensure
    if previous
      ENV["GITHUB_ACTIONS"] = previous
    else
      ENV.delete("GITHUB_ACTIONS")
    end
  end

  private

  def commands_for
    Security::Tools.all.to_h { |tool|
      instance = tool.new
      [ instance.name, instance.command ]
    }
  end
end
