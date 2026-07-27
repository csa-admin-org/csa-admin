# frozen_string_literal: true

require "test_helper"
require "open3"

class SyntaxWrapperTest < ActiveSupport::TestCase
  test "checks every supported project Ruby source form" do
    paths = %w[
      app/views/active_admin/attachments/_form.html.arb
      app/views/activity_participations_calendar/show.ics.ruby
      config.ru
      bin/ci
    ]

    output, error, status = Open3.capture3(
      Rails.root.join("bin/syntax").to_s,
      *paths,
      chdir: Rails.root.to_s)

    assert_predicate status, :success?, error
    assert_empty output
  end

  test "ignores a shell binstub" do
    output, error, status = Open3.capture3(
      Rails.root.join("bin/syntax").to_s,
      "bin/docker-entrypoint",
      chdir: Rails.root.to_s)

    assert_predicate status, :success?, error
    assert_equal "No Ruby files to check.\n", output
  end
end
