# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "style"
require "rbconfig"
require "tmpdir"

class Style::RunnerTest < ActiveSupport::TestCase
  test "returns outcomes for matching check tools only" do
    commands = []
    result = run_style(
      mode: :check,
      paths: %w[app/models/member.rb app/javascript/admin.js],
      executor: recording_executor(commands))

    assert result.success?
    assert_equal %i[syntax rubocop oxfmt oxlint], result.outcomes.map(&:name)
    assert_equal %w[bin/syntax bin/rubocop bin/oxfmt bin/oxlint], commands.map(&:first)
  end

  test "returns failure data without exiting" do
    result = run_style(
      mode: :check,
      paths: %w[app/models/member.rb],
      executor: ->(command) {
        command.first == "bin/rubocop" ? [ "Layout/LineLength: too long\n", false ] : [ "", true ]
      })

    assert result.failure?
    assert_equal "Style check failed: rubocop", result.failure_message
    assert_equal "Layout/LineLength: too long\n", result.outcomes.last.output
  end

  test "runs ordered fix phases then check-only verification" do
    commands = []
    groups = []
    mapper = ->(tools, &block) {
      groups << tools
      tools.map(&block)
    }

    result = Style::Runner.new(
      mode: :fix,
      paths: [],
      root: Style::ROOT,
      executor: recording_executor(commands),
      mapper:).call

    assert result.success?
    assert_equal [
      [ Style::Tools::Locales, Style::Tools::HerbFormat, Style::Tools::Oxfmt, Style::Tools::Prettier ],
      [ Style::Tools::Rubocop, Style::Tools::Oxlint, Style::Tools::Stylelint ],
      [ Style::Tools::Syntax, Style::Tools::HerbLint ]
    ], groups
    assert_equal [
      %w[bin/locales format],
      %w[bin/herb format .],
      %w[bin/oxfmt app/javascript],
      %w[bin/prettier app/assets/tailwind/**/*.css --write --cache --log-level warn],
      %w[bin/rubocop --parallel --autocorrect-all --format quiet],
      %w[bin/oxlint app/javascript --fix],
      %w[bin/stylelint app/assets/tailwind/**/*.css --fix],
      %w[bin/syntax],
      %w[bin/herb lint .]
    ], commands
  end

  test "continues later fix phases after a failure" do
    commands = []
    result = run_style(
      mode: :fix,
      paths: [],
      executor: ->(command) {
        commands << command
        command == %w[bin/locales format] ? [ "invalid locale\n", false ] : [ "", true ]
      })

    assert result.failure?
    assert_equal %i[locales], result.outcomes.reject(&:success?).map(&:name)
    assert_includes commands, %w[bin/syntax]
    assert_includes commands, %w[bin/herb lint .]
  end

  test "captures spawn errors and continues later fix phases" do
    commands = []
    result = run_style(
      mode: :fix,
      paths: [],
      executor: ->(command) {
        commands << command
        raise Errno::ENOENT, command.first if command == %w[bin/locales format]

        [ "", true ]
      })

    assert result.failure?
    assert_equal %i[locales], result.outcomes.reject(&:success?).map(&:name)
    assert_includes result.outcomes.first.output, "Errno::ENOENT"
    assert_includes commands, %w[bin/syntax]
    assert_includes commands, %w[bin/herb lint .]
  end

  test "uses a bounded thread pool for checks" do
    thread_counts = []
    parallel_map = ->(tools, in_threads:, &block) {
      thread_counts << in_threads
      tools.map(&block)
    }

    Parallel.stub(:map, parallel_map) do
      Style::Runner.new(
        mode: :check,
        paths: [],
        root: Style::ROOT,
        executor: ->(_command) { [ "", true ] }).call
    end

    assert_equal [ 3 ], thread_counts
  end

  test "executes commands from the configured root" do
    Dir.mktmpdir do |root|
      runner = Style::Runner.new(mode: :check, paths: [], root:)
      output, success = runner.send(:execute, [ RbConfig.ruby, "-e", "print Dir.pwd" ])

      assert success
      assert_equal File.realpath(root), output
    end
  end

  test "rejects invalid modes before running tools" do
    error = assert_raises(ArgumentError) do
      Style::Runner.new(mode: :format, paths: [], root: Style::ROOT)
    end

    assert_equal "invalid style mode: :format", error.message
  end

  test "returns an unmatched successful result" do
    commands = []
    result = run_style(
      mode: :check,
      paths: %w[README.md],
      executor: recording_executor(commands))

    assert result.success?
    assert result.unmatched?
    assert_empty commands
  end

  private

  def run_style(mode:, paths:, executor:)
    Style::Runner.new(
      mode:,
      paths:,
      root: Style::ROOT,
      executor:,
      mapper: ->(tools, &block) { tools.map(&block) }).call
  end

  def recording_executor(commands)
    ->(command) {
      commands << command
      [ "", true ]
    }
  end
end
