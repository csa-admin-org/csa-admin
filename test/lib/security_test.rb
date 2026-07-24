# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "open3"
require "rbconfig"
require "security"
require "tmpdir"

class SecurityTest < ActiveSupport::TestCase
  test "reports a successful run without exiting" do
    result = Security::Result.new(
      outcomes: [ Security::Outcome.from(name: :brakeman, success: true, output: "") ])

    out, = capture_io do
      Security.stub(:run, -> { result }) do
        assert_same result, Security.run!
      end
    end

    assert_equal "✅ brakeman\n", out
  end

  test "reports failures and exits at the entry point" do
    result = Security::Result.new(
      outcomes: [ Security::Outcome.from(name: :brakeman, success: false, output: "Dangerous send\n") ])

    error = nil
    out, err = capture_io do
      Security.stub(:run, -> { result }) do
        error = assert_raises(SystemExit) { Security.run! }
      end
    end

    assert_equal 1, error.status
    assert_equal "❌ brakeman\nDangerous send\n\n", out
    assert_equal "Security check failed: brakeman\n", err
  end

  test "bin security uses the project bundle and delegates outside the repository" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "security.rb"), fake_security)

      script = <<~RUBY
        $LOAD_PATH.unshift(#{directory.inspect})
        require "security"
        load #{File.join(Security::ROOT, "bin/security").inspect}
      RUBY
      out, err, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => nil },
        RbConfig.ruby,
        "-e",
        script,
        chdir: Dir.tmpdir)

      assert_predicate status, :success?, err
      assert_equal "Security ran\n", out
    end
  end

  test "security library loads outside the repository without Rails" do
    script = <<~RUBY
      ENV["BUNDLE_GEMFILE"] = #{File.join(Security::ROOT, "Gemfile").inspect}
      require "bundler/setup"
      $LOAD_PATH.unshift(#{File.join(Security::ROOT, "lib").inspect})
      require "security"
      abort "Rails loaded" if defined?(Rails)
    RUBY

    _, err, status = Open3.capture3(
      { "BUNDLE_GEMFILE" => nil },
      RbConfig.ruby,
      "-e",
      script,
      chdir: Dir.tmpdir)

    assert_predicate status, :success?, err
  end

  private

  def fake_security
    <<~RUBY
      module Security
        def self.run!
          abort "Rails loaded" if defined?(Rails)
          abort "wrong BUNDLE_GEMFILE" unless ENV["BUNDLE_GEMFILE"] == #{File.join(Security::ROOT, "Gemfile").inspect}

          puts "Security ran"
        end
      end
    RUBY
  end
end
