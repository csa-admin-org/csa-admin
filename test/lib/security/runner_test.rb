# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "rbconfig"
require "security"
require "tmpdir"

class Security::RunnerTest < ActiveSupport::TestCase
  class ConcurrencyProbe
    DELAYS = {
      "bin/bundler-audit" => 0.06,
      "bin/importmap" => 0.04,
      "bin/brakeman" => 0.02,
      "bin/aube" => 0
    }.freeze

    attr_reader :peak

    def initialize(required:)
      @required = required
      @active = 0
      @peak = 0
      @mutex = Mutex.new
      @condition = ConditionVariable.new
    end

    def call(command)
      start
      sleep DELAYS.fetch(command.first)
    ensure
      finish
    end

    private

    def start
      @mutex.synchronize do
        @active += 1
        @peak = [ @peak, @active ].max
        @peak == @required ? @condition.broadcast : @condition.wait(@mutex) { @peak == @required }
      end
    end

    def finish
      @mutex.synchronize { @active -= 1 }
    end
  end

  test "returns ordered outcomes without reporting or exiting" do
    commands = []
    result = run_security(executor: recording_executor(commands))

    assert result.success?
    assert_equal %i[bundler_audit importmap brakeman aube], result.outcomes.map(&:name)
    assert_equal [
      %w[bin/bundler-audit check --update],
      %w[bin/importmap audit],
      %w[bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error],
      %w[bin/aube audit]
    ], commands
  end

  test "returns failure data without exiting" do
    result = run_security(executor: ->(command) {
      command.first == "bin/brakeman" ? [ "Dangerous send\n", false ] : [ "", true ]
    })

    assert result.failure?
    assert_equal "Security check failed: brakeman", result.failure_message
    assert_equal "Dangerous send\n", result.outcomes.third.output
  end

  test "captures spawn errors and continues later tools" do
    commands = []
    result = run_security(executor: ->(command) {
      commands << command
      raise Errno::ENOENT, command.first if command.first == "bin/importmap"

      [ "", true ]
    })

    assert result.failure?
    assert_equal %i[importmap], result.outcomes.reject(&:success?).map(&:name)
    assert_includes result.outcomes.second.output, "Errno::ENOENT"
    assert_includes commands, %w[bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error]
    assert_includes commands, %w[bin/aube audit]
  end

  test "bounds concurrent checks and preserves tool order" do
    concurrency = ConcurrencyProbe.new(required: Security::Runner::MAX_THREADS)
    result = Security::Runner.new(
      root: Security::ROOT,
      executor: ->(command) {
        concurrency.call(command)
        [ "", true ]
      }).call

    assert_equal Security::Runner::MAX_THREADS, concurrency.peak
    assert_equal %i[bundler_audit importmap brakeman aube], result.outcomes.map(&:name)
  end

  test "executes commands from the configured root" do
    Dir.mktmpdir do |root|
      runner = Security::Runner.new(root:)
      output, success = runner.send(:execute, [ RbConfig.ruby, "-e", "print Dir.pwd" ])

      assert success
      assert_equal File.realpath(root), output
    end
  end

  private

  def run_security(executor:)
    Security::Runner.new(
      root: Security::ROOT,
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
