# frozen_string_literal: true

require "test_helper"
require "style"

class Style::RunnerTest < ActiveSupport::TestCase
  test "prints success marks for matching tools only" do
    commands = []
    executor = ->(command) {
      commands << command
      [ "", true ]
    }

    out, = capture_io {
      run_style(
        mode: :check,
        paths: %w[app/models/member.rb app/javascript/admin.js],
        executor: executor)
    }

    assert_includes out, "✅ rubocop"
    assert_includes out, "✅ oxfmt"
    assert_includes out, "✅ oxlint"
    assert_not_includes out, "prettier"
    assert_equal 3, commands.size
    assert commands.any? { |command| command.start_with?("bin/rubocop") }
    assert commands.any? { |command| command.start_with?("bin/oxfmt") }
    assert commands.any? { |command| command.start_with?("bin/oxlint") }
  end

  test "prints failure output then aborts with failed tool names" do
    executor = ->(_command) { [ "Layout/LineLength: too long\n", false ] }

    error = nil
    out, err = capture_io {
      error = assert_raises(SystemExit) {
        run_style(
          mode: :check,
          paths: %w[app/models/member.rb],
          executor: executor)
      }
    }

    assert_equal 1, error.status
    assert_includes out, "❌ rubocop"
    assert_includes out, "Layout/LineLength: too long"
    assert_includes err, "Style check failed: rubocop"
  end

  test "prints outcomes in completion order" do
    timed = [
      Style::Outcome.new(name: :rubocop, success: true, output: "", finished_at: 3.0),
      Style::Outcome.new(name: :oxfmt, success: false, output: "boom\n", finished_at: 1.0),
      Style::Outcome.new(name: :oxlint, success: true, output: "", finished_at: 2.0)
    ]
    runner = Style::Runner.new(
      mode: :check,
      paths: [],
      mapper: ->(_enum, &_block) { timed })

    out, err = capture_io {
      assert_raises(SystemExit) { runner.call }
    }

    assert_equal <<~OUTPUT, out
      ❌ oxfmt
      boom

      ✅ oxlint
      ✅ rubocop
    OUTPUT
    assert_includes err, "Style check failed: oxfmt"
  end

  test "succeeds when no tool matches the given paths" do
    commands = []

    capture_io {
      run_style(
        mode: :check,
        paths: %w[README.md],
        executor: ->(command) {
          commands << command
          [ "", true ]
        })
    }

    assert_empty commands
  end

  private

  def run_style(mode:, paths:, executor:)
    Style::Runner.new(
      mode: mode,
      paths: paths,
      executor: executor,
      mapper: ->(enum, &block) { enum.map(&block) }).call
  end
end
