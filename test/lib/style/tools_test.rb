# frozen_string_literal: true

require "test_helper"
require "style"

class Style::ToolsTest < ActiveSupport::TestCase
  test "full check run uses default scopes for every tool" do
    commands = commands_for(:check, [])

    assert_equal "bin/locales check", commands[:locales]
    assert_equal "bin/syntax", commands[:syntax]
    assert_equal "bin/rubocop --parallel --format simple", commands[:rubocop]
    assert_equal "bin/herb lint .", commands[:herb_lint]
    assert_equal "bin/herb format . --check", commands[:herb_format]
    assert_equal "bin/oxfmt app/javascript --check", commands[:oxfmt]
    assert_equal "bin/oxlint app/javascript", commands[:oxlint]
    assert_equal 'bin/prettier "app/assets/tailwind/**/*.css" --check --cache --log-level warn',
      commands[:prettier]
    assert_equal 'bin/stylelint "app/assets/tailwind/**/*.css"', commands[:stylelint]
  end

  test "herb lint adds --github under GitHub Actions" do
    previous = ENV["GITHUB_ACTIONS"]
    ENV["GITHUB_ACTIONS"] = "true"

    commands = commands_for(:check, [])

    assert_equal "bin/herb lint . --github", commands[:herb_lint]
  ensure
    if previous
      ENV["GITHUB_ACTIONS"] = previous
    else
      ENV.delete("GITHUB_ACTIONS")
    end
  end

  test "full fix run uses fix flags and skips check-only tools" do
    commands = commands_for(:fix, [])

    assert_equal "bin/locales format", commands[:locales]
    assert_nil commands[:syntax]
    assert_equal "bin/rubocop --parallel --autocorrect-all --format quiet", commands[:rubocop]
    assert_nil commands[:herb_lint]
    assert_equal "bin/herb format .", commands[:herb_format]
    assert_equal "bin/oxfmt app/javascript", commands[:oxfmt]
    assert_equal "bin/oxlint app/javascript --fix", commands[:oxlint]
    assert_equal 'bin/prettier "app/assets/tailwind/**/*.css" --write --cache --log-level warn',
      commands[:prettier]
    assert_equal 'bin/stylelint "app/assets/tailwind/**/*.css" --fix', commands[:stylelint]
  end

  test "ruby path only runs syntax and rubocop" do
    commands = commands_for(:check, %w[app/models/member.rb])

    assert_equal "bin/syntax app/models/member.rb", commands[:syntax]
    assert_equal(
      "bin/rubocop --parallel --format simple --only-recognized-file-types app/models/member.rb",
      commands[:rubocop])
    assert_only commands, :syntax, :rubocop
  end

  test "javascript path only runs oxfmt and oxlint" do
    commands = commands_for(:check, %w[app/javascript/admin.js])

    assert_equal "bin/oxfmt app/javascript/admin.js --check", commands[:oxfmt]
    assert_equal "bin/oxlint app/javascript/admin.js", commands[:oxlint]
    assert_only commands, :oxfmt, :oxlint
  end

  test "erb path runs herb tools and rubocop" do
    path = "app/views/active_admin/_flash_messages.html.erb"
    commands = commands_for(:check, [ path ])

    assert_equal "bin/herb lint #{path}", commands[:herb_lint]
    assert_equal "bin/herb format #{path} --check", commands[:herb_format]
    assert_includes commands[:rubocop], path
    assert_only commands, :herb_lint, :herb_format, :rubocop
  end

  test "css path only runs prettier and stylelint" do
    path = "app/assets/tailwind/application.css"
    commands = commands_for(:check, [ path ])

    assert_equal "bin/prettier #{path} --check --cache --log-level warn", commands[:prettier]
    assert_equal "bin/stylelint #{path}", commands[:stylelint]
    assert_only commands, :prettier, :stylelint
  end

  test "locale path only runs locales" do
    commands = commands_for(:check, %w[config/locales/en.yml])

    assert_equal "bin/locales check", commands[:locales]
    assert_only commands, :locales
  end

  test "mixed paths run each matching tool with its own files" do
    paths = %w[
      app/models/member.rb
      app/javascript/admin.js
      app/assets/tailwind/application.css
    ]
    commands = commands_for(:check, paths)

    assert_equal "bin/syntax app/models/member.rb", commands[:syntax]
    assert_includes commands[:rubocop], "app/models/member.rb"
    assert_includes commands[:oxfmt], "app/javascript/admin.js"
    assert_includes commands[:oxlint], "app/javascript/admin.js"
    assert_includes commands[:prettier], "app/assets/tailwind/application.css"
    assert_includes commands[:stylelint], "app/assets/tailwind/application.css"
    assert_nil commands[:locales]
    assert_nil commands[:herb_lint]
    assert_nil commands[:herb_format]
  end

  test "shell-escapes paths with spaces" do
    path = "app/models/my model.rb"
    commands = commands_for(:check, [ path ])

    assert_includes commands[:syntax], "app/models/my\\ model.rb"
    assert_includes commands[:rubocop], "app/models/my\\ model.rb"
  end

  test "unmatched paths skip every tool" do
    commands = commands_for(:check, %w[README.md docs/notes.txt])

    assert_empty commands.compact
  end

  private

  def commands_for(mode, paths)
    Style::Tools.all.to_h { |tool|
      instance = tool.new(paths)
      [ instance.name, instance.command(mode) ]
    }
  end

  def assert_only(commands, *names)
    present = commands.compact.keys
    assert_equal names.sort, present.sort, "unexpected tools: #{present - names}"
  end
end
