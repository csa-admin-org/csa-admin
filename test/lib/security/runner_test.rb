# frozen_string_literal: true

require "test_helper"
require "security"

class Security::RunnerTest < ActiveSupport::TestCase
  test "prints success marks for every tool" do
    commands = []
    executor = ->(command) {
      commands << command
      [ "", true ]
    }

    out, = capture_io {
      Security::Runner.new(
        executor: executor,
        mapper: ->(enum, &block) { enum.map(&block) }).call
    }

    assert_includes out, "✅ bundler_audit"
    assert_includes out, "✅ importmap"
    assert_includes out, "✅ brakeman"
    assert_includes out, "✅ aube"
    assert_equal 4, commands.size
  end

  test "prints failure output then aborts with failed tool names" do
    executor = ->(command) {
      if command.start_with?("bin/brakeman")
        [ "Dangerous send\n", false ]
      else
        [ "", true ]
      end
    }

    error = nil
    out, err = capture_io {
      error = assert_raises(SystemExit) {
        Security::Runner.new(
          executor: executor,
          mapper: ->(enum, &block) { enum.map(&block) }).call
      }
    }

    assert_equal 1, error.status
    assert_includes out, "❌ brakeman"
    assert_includes out, "Dangerous send"
    assert_includes err, "Security check failed: brakeman"
  end
end
