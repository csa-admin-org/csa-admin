# frozen_string_literal: true

require "test_helper"
require "style"

class Style::ToolsTest < ActiveSupport::TestCase
  setup do
    @previous_github_actions = ENV["GITHUB_ACTIONS"]
    ENV.delete("GITHUB_ACTIONS")
  end

  teardown do
    if @previous_github_actions
      ENV["GITHUB_ACTIONS"] = @previous_github_actions
    else
      ENV.delete("GITHUB_ACTIONS")
    end
  end

  test "full check run uses default scopes for every tool" do
    commands = commands_for(:check, [])

    assert_equal %w[bin/locales check], commands[:locales]
    assert_equal %w[bin/syntax], commands[:syntax]
    assert_equal %w[bin/rubocop --parallel --format simple], commands[:rubocop]
    assert_equal %w[bin/actionlint], commands[:actionlint]
    assert_equal %w[bin/herb lint .], commands[:herb_lint]
    assert_equal %w[bin/herb format . --check], commands[:herb_format]
    assert_equal %w[bin/oxfmt app/javascript --check], commands[:oxfmt]
    assert_equal %w[bin/oxlint app/javascript], commands[:oxlint]
    assert_equal [
      "bin/prettier",
      "app/assets/tailwind/**/*.css",
      "app/assets/stylesheets/mailer.css",
      "package.json",
      ".prettierrc",
      ".stylelintrc.json",
      ".oxfmtrc.json",
      ".oxlintrc.json",
      "--check",
      "--cache",
      "--log-level",
      "warn"
    ], commands[:prettier]
    assert_equal %w[
      bin/stylelint
      app/assets/tailwind/**/*.css
      app/assets/stylesheets/mailer.css
    ], commands[:stylelint]
  end

  test "herb lint adds --github under GitHub Actions" do
    ENV["GITHUB_ACTIONS"] = "true"

    commands = commands_for(:check, [])

    assert_equal %w[bin/herb lint . --github], commands[:herb_lint]
  end

  test "full fix run uses fix flags and skips check-only tools" do
    commands = commands_for(:fix, [])

    assert_equal %w[bin/locales format], commands[:locales]
    assert_nil commands[:syntax]
    assert_equal %w[bin/rubocop --parallel --autocorrect-all --format quiet], commands[:rubocop]
    assert_nil commands[:actionlint]
    assert_nil commands[:herb_lint]
    assert_equal %w[bin/herb format .], commands[:herb_format]
    assert_equal %w[bin/oxfmt app/javascript], commands[:oxfmt]
    assert_equal %w[bin/oxlint app/javascript --fix], commands[:oxlint]
    assert_equal [
      "bin/prettier",
      "app/assets/tailwind/**/*.css",
      "app/assets/stylesheets/mailer.css",
      "package.json",
      ".prettierrc",
      ".stylelintrc.json",
      ".oxfmtrc.json",
      ".oxlintrc.json",
      "--write",
      "--cache",
      "--log-level",
      "warn"
    ], commands[:prettier]
    assert_equal %w[
      bin/stylelint
      app/assets/tailwind/**/*.css
      app/assets/stylesheets/mailer.css
      --fix
    ], commands[:stylelint]
  end

  test "ruby path only runs syntax and rubocop" do
    commands = commands_for(:check, %w[app/models/member.rb])

    assert_equal %w[bin/syntax app/models/member.rb], commands[:syntax]
    assert_equal(
      %w[bin/rubocop --parallel --format simple --only-recognized-file-types app/models/member.rb],
      commands[:rubocop])
    assert_only commands, :syntax, :rubocop
  end

  test "ruby directory only runs syntax and rubocop" do
    commands = commands_for(:check, %w[app/models])

    assert_equal %w[bin/syntax app/models], commands[:syntax]
    assert_equal(
      %w[bin/rubocop --parallel --format simple --only-recognized-file-types app/models],
      commands[:rubocop])
    assert_only commands, :syntax, :rubocop
  end

  test "expanded ruby sources run syntax and rubocop" do
    paths = %w[
      app/views/active_admin/attachments/_form.html.arb
      app/views/activity_participations_calendar/show.ics.ruby
      config.ru
      bin/style
    ]
    commands = commands_for(:check, paths)

    paths.each do |path|
      assert_includes commands[:syntax], path
      assert_includes commands[:rubocop], path
    end
    assert_only commands, :syntax, :rubocop
  end

  test "shell binstub does not run ruby tools" do
    commands = commands_for(:check, %w[bin/docker-entrypoint])

    assert_empty commands.compact
  end

  test "javascript path only runs oxfmt and oxlint" do
    commands = commands_for(:check, %w[app/javascript/admin.js])

    assert_equal %w[bin/oxfmt app/javascript/admin.js --check], commands[:oxfmt]
    assert_equal %w[bin/oxlint app/javascript/admin.js], commands[:oxlint]
    assert_only commands, :oxfmt, :oxlint
  end

  test "erb path runs herb tools and rubocop" do
    path = "app/views/active_admin/_flash_messages.html.erb"
    commands = commands_for(:check, [ path ])

    assert_equal [ "bin/herb", "lint", path ], commands[:herb_lint]
    assert_equal [ "bin/herb", "format", path, "--check" ], commands[:herb_format]
    assert_includes commands[:rubocop], path
    assert_only commands, :herb_lint, :herb_format, :rubocop
  end

  test "template directory containing arb files also runs syntax" do
    path = "app/views/active_admin"
    commands = commands_for(:check, [ path ])

    assert_equal [ "bin/syntax", path ], commands[:syntax]
    assert_equal [ "bin/herb", "lint", path ], commands[:herb_lint]
    assert_equal [ "bin/herb", "format", path, "--check" ], commands[:herb_format]
    assert_includes commands[:rubocop], path
    assert_only commands, :syntax, :herb_lint, :herb_format, :rubocop
  end

  test "css path only runs prettier and stylelint" do
    path = "app/assets/tailwind/application.css"
    commands = commands_for(:check, [ path ])

    assert_equal [ "bin/prettier", path, "--check", "--cache", "--log-level", "warn" ],
      commands[:prettier]
    assert_equal [ "bin/stylelint", path ], commands[:stylelint]
    assert_only commands, :prettier, :stylelint
  end

  test "mailer css path only runs prettier and stylelint" do
    path = "app/assets/stylesheets/mailer.css"
    commands = commands_for(:check, [ path ])

    assert_equal [ "bin/prettier", path, "--check", "--cache", "--log-level", "warn" ],
      commands[:prettier]
    assert_equal [ "bin/stylelint", path ], commands[:stylelint]
    assert_only commands, :prettier, :stylelint
  end

  test "css ancestor directory remains scoped to owned stylesheets" do
    commands = commands_for(:check, %w[app/assets])

    assert_equal %w[
      bin/prettier
      app/assets/tailwind
      app/assets/stylesheets/mailer.css
      --check
      --cache
      --log-level
      warn
    ], commands[:prettier]
    assert_equal %w[
      bin/stylelint
      app/assets/tailwind
      app/assets/stylesheets/mailer.css
    ], commands[:stylelint]
    assert_only commands, :prettier, :stylelint
  end

  test "project json configuration only runs prettier" do
    paths = %w[package.json .prettierrc .stylelintrc.json .oxfmtrc.json .oxlintrc.json]
    commands = commands_for(:check, paths)

    assert_equal [ "bin/prettier", *paths, "--check", "--cache", "--log-level", "warn" ],
      commands[:prettier]
    assert_only commands, :prettier
  end

  test "project root maps prettier and stylelint to exact owned targets" do
    commands = commands_for(:check, %w[.])

    assert_equal [
      "bin/prettier",
      "app/assets/tailwind",
      "app/assets/stylesheets/mailer.css",
      "package.json",
      ".prettierrc",
      ".stylelintrc.json",
      ".oxfmtrc.json",
      ".oxlintrc.json",
      "--check",
      "--cache",
      "--log-level",
      "warn"
    ], commands[:prettier]
    assert_equal %w[
      bin/stylelint
      app/assets/tailwind
      app/assets/stylesheets/mailer.css
    ], commands[:stylelint]
    assert_not_includes commands[:prettier], "."
  end

  test "workflow file only runs actionlint" do
    path = ".github/workflows/ci.yml"
    commands = commands_for(:check, [ path ])

    assert_equal [ "bin/actionlint", path ], commands[:actionlint]
    assert_only commands, :actionlint
  end

  test "workflow directory lets actionlint discover all workflows" do
    commands = commands_for(:check, %w[.github])

    assert_equal %w[bin/actionlint], commands[:actionlint]
    assert_only commands, :actionlint
  end

  test "locale path only runs locales" do
    commands = commands_for(:check, %w[config/locales/en.yml])

    assert_equal %w[bin/locales check], commands[:locales]
    assert_only commands, :locales
  end

  test "mixed paths run each matching tool with its own files" do
    paths = %w[
      app/models/member.rb
      app/javascript/admin.js
      app/assets/tailwind/application.css
    ]
    commands = commands_for(:check, paths)

    assert_equal %w[bin/syntax app/models/member.rb], commands[:syntax]
    assert_includes commands[:rubocop], "app/models/member.rb"
    assert_includes commands[:oxfmt], "app/javascript/admin.js"
    assert_includes commands[:oxlint], "app/javascript/admin.js"
    assert_includes commands[:prettier], "app/assets/tailwind/application.css"
    assert_includes commands[:stylelint], "app/assets/tailwind/application.css"
    assert_nil commands[:locales]
    assert_nil commands[:herb_lint]
    assert_nil commands[:herb_format]
  end

  test "preserves special characters in path arguments" do
    paths = [ "app/models/my model.rb", "app/models/member'$HOME;name.rb" ]
    commands = commands_for(:check, paths)

    paths.each do |path|
      assert_includes commands[:syntax], path
      assert_includes commands[:rubocop], path
    end
  end

  test "unmatched paths skip every tool" do
    commands = commands_for(:check, %w[README.md docs/notes.txt manifest.json])

    assert_empty commands.compact
  end

  private

  def commands_for(mode, paths)
    Style::Tools.all.to_h { |tool|
      instance = tool.new(paths, root: Style::ROOT)
      [ instance.name, instance.command(mode) ]
    }
  end

  def assert_only(commands, *names)
    present = commands.compact.keys
    assert_equal names.sort, present.sort, "unexpected tools: #{present - names}"
  end
end
