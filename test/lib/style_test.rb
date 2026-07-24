# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "open3"
require "rbconfig"
require "style"
require "tmpdir"

class StyleTest < ActiveSupport::TestCase
  test "reports a successful run without exiting" do
    result = Style::Result.new(
      mode: :check,
      paths: [],
      outcomes: [ Style::Outcome.from(name: :rubocop, success: true, output: "") ])

    out, = capture_io do
      Style.stub(:run, ->(_mode, paths: []) { result }) do
        assert_same result, Style.run!(:check)
      end
    end

    assert_equal "✅ rubocop\n", out
  end

  test "reports failures and exits at the entry point" do
    result = Style::Result.new(
      mode: :check,
      paths: [],
      outcomes: [ Style::Outcome.from(name: :rubocop, success: false, output: "broken\n") ])

    error = nil
    out, err = capture_io do
      Style.stub(:run, ->(_mode, paths: []) { result }) do
        error = assert_raises(SystemExit) { Style.run!(:check) }
      end
    end

    assert_equal 1, error.status
    assert_equal "❌ rubocop\nbroken\n\n", out
    assert_equal "Style check failed: rubocop\n", err
  end

  test "reports unmatched paths as a successful no-op" do
    result = Style::Result.new(mode: :check, paths: %w[README.md], outcomes: [])

    out, = capture_io do
      Style.stub(:run, ->(_mode, paths: []) { result }) do
        assert_same result, Style.run!(:check, paths: %w[README.md])
      end
    end

    assert_equal "No style tools matched: README.md\n", out
  end

  test "bin style runs outside the repository without loading Rails" do
    script = <<~RUBY
      ARGV.replace(["README.md"])
      load #{File.join(Style::ROOT, "bin/style").inspect}
      abort "Rails loaded" if defined?(Rails)
    RUBY

    out, err, status = Open3.capture3(
      { "BUNDLE_GEMFILE" => nil },
      RbConfig.ruby,
      "-e",
      script,
      chdir: Dir.tmpdir)

    assert_predicate status, :success?, err
    assert_equal "No style tools matched: README.md\n", out
  end

  test "rejects paths outside the repository at the entry point" do
    outside = File.expand_path("..", Style::ROOT)

    error = nil
    _, err = capture_io do
      error = assert_raises(SystemExit) { Style.run!(:check, paths: [ outside ]) }
    end

    assert_equal 1, error.status
    assert_equal "Style check failed: path outside repository: #{outside}\n", err
  end
end
