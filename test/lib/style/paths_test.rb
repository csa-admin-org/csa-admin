# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "style/paths"
require "tmpdir"

class Style::PathsTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
  end

  teardown do
    FileUtils.remove_entry @root
  end

  test "normalizes paths relative to an explicit repository root" do
    paths = Style::Paths.normalize(
      [ "./app/models/member.rb", "app/models/../models/member.rb", File.join(@root, "lib/style.rb") ],
      root: @root)

    assert_equal %w[app/models/member.rb lib/style.rb], paths
  end

  test "normalizes the repository root to dot" do
    assert_equal [ "." ], Style::Paths.normalize([ @root ], root: @root)
  end

  test "rejects lexical paths outside the repository root" do
    error = assert_raises(Style::Paths::OutsideRootError) do
      Style::Paths.normalize([ "app/../../outside.rb" ], root: @root)
    end

    assert_equal "path outside repository: app/../../outside.rb", error.message
  end

  test "rejects a symlink to a directory outside the repository" do
    Dir.mktmpdir do |outside|
      FileUtils.mkdir_p File.join(@root, "app")
      File.symlink outside, File.join(@root, "app/external")

      assert_raises(Style::Paths::OutsideRootError) do
        Style::Paths.normalize([ "app/external/member.rb" ], root: @root)
      end
    end
  end

  test "rejects a symlink to a file outside the repository" do
    Dir.mktmpdir do |outside|
      external_file = File.join(outside, "member.rb")
      File.write external_file, ""
      FileUtils.mkdir_p File.join(@root, "app/models")
      File.symlink external_file, File.join(@root, "app/models/member.rb")

      assert_raises(Style::Paths::OutsideRootError) do
        Style::Paths.normalize([ "app/models/member.rb" ], root: @root)
      end
    end
  end
end
