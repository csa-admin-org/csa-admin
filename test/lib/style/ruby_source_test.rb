# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "style/ruby_source"
require "tmpdir"

class Style::RubySourceTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
  end

  teardown do
    FileUtils.remove_entry @root
  end

  test "recognizes supported extensions and basenames" do
    paths = %w[
      admin.arb
      application.gemspec
      task.rake
      model.rb
      config.ru
      calendar.ics.ruby
      Gemfile
      Rakefile
    ]

    paths.each do |path|
      assert Style::RubySource.source?(path, root: @root)
    end
  end

  test "recognizes extensionless Ruby scripts by shebang" do
    write_file "bin/tool", "#!/usr/bin/env ruby\nputs :ok\n"

    assert Style::RubySource.source?("bin/tool", root: @root)
  end

  test "rejects extensionless non-Ruby files" do
    write_file "bin/tool", "#!/bin/sh\necho ok\n"
    write_file ".DS_Store", "\xFF\xFE".b

    assert_not Style::RubySource.source?("bin/tool", root: @root)
    assert_not Style::RubySource.source?("README", root: @root)
    assert_not Style::RubySource.source?(".DS_Store", root: @root)
  end

  test "preserves only directories containing Ruby sources" do
    write_file "ruby/tool", "#!/usr/bin/env ruby\n"
    write_file "shell/tool", "#!/bin/sh\n"

    selected = Style::RubySource.select(%w[ruby shell], root: @root)

    assert_equal %w[ruby], selected
  end

  private

  def write_file(path, content)
    file = File.join(@root, path)
    FileUtils.mkdir_p File.dirname(file)
    File.binwrite file, content
  end
end
