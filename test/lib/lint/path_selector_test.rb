# frozen_string_literal: true

require "test_helper"
require "lint"

class Lint::PathSelectorTest < ActiveSupport::TestCase
  test "matches extension globs" do
    paths = %w[
      app/models/member.rb
      lib/tasks/lint.rake
      app/javascript/admin.js
    ]

    selected = Lint::PathSelector.call(paths, patterns: %w[**/*.{rb,rake}])

    assert_equal %w[app/models/member.rb lib/tasks/lint.rake], selected
  end

  test "matches path prefixes for files and directories" do
    paths = %w[
      app/javascript/admin.js
      app/javascript
      app/models/member.rb
    ]

    selected = Lint::PathSelector.call(paths, prefixes: %w[app/javascript])

    assert_equal %w[app/javascript/admin.js app/javascript], selected
  end

  test "matches herb-style templates" do
    paths = %w[
      app/views/members/show.html.erb
      app/views/members/index.turbo_stream.erb
      app/views/mailer.text.erb
    ]

    selected = Lint::PathSelector.call(
      paths,
      patterns: %w[**/*.html.erb **/*.turbo_stream.erb])

    assert_equal %w[
      app/views/members/show.html.erb
      app/views/members/index.turbo_stream.erb
    ], selected
  end

  test "returns empty when nothing matches" do
    selected = Lint::PathSelector.call(
      %w[README.md],
      patterns: %w[**/*.rb],
      prefixes: %w[app/javascript])

    assert_empty selected
  end
end
