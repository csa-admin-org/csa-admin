# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "open3"
require "rake"

class StyleRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("style")
    %w[style style:check style:fix].each { |name| Rake::Task[name].reenable }
  end

  test "whole-project style tasks delegate to the expected modes" do
    calls = []

    Style.stub(:run!, ->(mode, paths: []) { calls << [ mode, paths ] }) do
      Rake::Task["style"].invoke
      Rake::Task["style:fix"].invoke
    end

    assert_equal [ [ :check, [] ], [ :fix, [] ] ], calls
  end

  test "style is an alias for style check" do
    assert_equal [ "style:check" ], Rake::Task["style"].prerequisites
  end

  test "rejects positional paths" do
    out, err, status = Open3.capture3(
      "bin/rails",
      "style:check",
      "app/models/member.rb",
      chdir: Rails.root.to_s)

    assert_not_predicate status, :success?
    assert_includes "#{out}\n#{err}", 'Unrecognized command "app/models/member.rb"'
  end
end
