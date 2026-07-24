# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "style/path_selector"
require "tmpdir"

class Style::PathSelectorTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
    write_file "app/models/member.rb"
    write_file "app/models/member.txt"
    write_file "app/assets/tailwind/application.css"
    write_file "app/assets/other.css"
    write_file "app/javascript/admin.js"
    write_file "config/locales/en.yml"
  end

  teardown do
    FileUtils.remove_entry @root
  end

  test "matches extension globs" do
    paths = %w[
      app/models/member.rb
      lib/tasks/style.rake
      app/javascript/admin.js
    ]

    selected = Style::PathSelector.call(paths, patterns: %w[**/*.{rb,rake}], root: @root)

    assert_equal %w[app/models/member.rb lib/tasks/style.rake], selected
  end

  test "preserves matching directory arguments for patterns" do
    selected = Style::PathSelector.call(
      %w[app/models app/models/member.rb app/models],
      patterns: %w[**/*.rb],
      root: @root)

    assert_equal %w[app/models app/models/member.rb], selected
  end

  test "matches paths at or below configured prefixes" do
    selected = Style::PathSelector.call(
      %w[app/javascript app/javascript/admin.js app/javascriptian],
      prefixes: %w[app/javascript],
      root: @root)

    assert_equal %w[app/javascript app/javascript/admin.js], selected
  end

  test "maps supplied ancestor directories to configured prefixes" do
    selected = Style::PathSelector.call(
      %w[. app app/assets],
      prefixes: %w[app/assets/tailwind],
      root: @root)

    assert_equal %w[app/assets/tailwind], selected
  end

  test "maps the project root to a configured prefix" do
    selected = Style::PathSelector.call(
      %w[.],
      prefixes: %w[app/javascript],
      root: @root)

    assert_equal %w[app/javascript], selected
  end

  test "uses the configured prefix instead of an ancestor pattern directory" do
    selected = Style::PathSelector.call(
      %w[app/assets],
      patterns: %w[app/assets/tailwind/**/*.css],
      prefixes: %w[app/assets/tailwind],
      root: @root)

    assert_equal %w[app/assets/tailwind], selected
  end

  test "matches directories against repository-relative patterns" do
    selected = Style::PathSelector.call(
      %w[config],
      patterns: %w[config/locales/**/*.{yml,yaml}],
      root: @root)

    assert_equal %w[config], selected
  end

  test "matches herb-style templates" do
    paths = %w[
      app/views/members/show.html.erb
      app/views/members/index.turbo_stream.erb
      app/views/mailer.text.erb
    ]
    paths.each { |path| write_file path }

    selected = Style::PathSelector.call(
      paths,
      patterns: %w[**/*.html.erb **/*.turbo_stream.erb],
      root: @root)

    assert_equal %w[
      app/views/members/show.html.erb
      app/views/members/index.turbo_stream.erb
    ], selected
  end

  test "returns empty when nothing matches" do
    selected = Style::PathSelector.call(
      %w[README.md],
      patterns: %w[**/*.rb],
      prefixes: %w[app/javascript],
      root: @root)

    assert_empty selected
  end

  private

  def write_file(path)
    file = File.join(@root, path)
    FileUtils.mkdir_p File.dirname(file)
    File.write file, ""
  end
end
