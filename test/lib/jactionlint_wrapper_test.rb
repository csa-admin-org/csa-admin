# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

class JactionlintWrapperTest < ActiveSupport::TestCase
  test "uses the mise-configured jactionlint instead of the ambient executable" do
    expected, expected_error, expected_status = Open3.capture3(
      "mise", "exec", "--", "jactionlint", "--version", chdir: Rails.root.to_s)

    Dir.mktmpdir do |directory|
      write_fake_jactionlint(directory)
      actual, actual_error, actual_status = Open3.capture3(
        { "PATH" => "#{directory}:#{ENV.fetch("PATH")}" },
        Rails.root.join("bin/jactionlint").to_s,
        "--version",
        chdir: Dir.tmpdir)

      assert_predicate expected_status, :success?, expected_error
      assert_predicate actual_status, :success?, actual_error
      assert_equal expected, actual
      assert_not_equal "ambient jactionlint\n", actual
    end
  end

  private

  def write_fake_jactionlint(directory)
    path = File.join(directory, "jactionlint")
    File.write(path, "#!/bin/sh\necho 'ambient jactionlint'\n")
    File.chmod(0o755, path)
  end
end
