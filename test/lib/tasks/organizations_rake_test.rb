# frozen_string_literal: true

require "test_helper"
require "rake"

class OrganizationsRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("organizations:next_fiscal_year")
    Rake::Task["organizations:next_fiscal_year"].reenable
  end

  test "lists organizations grouped by next fiscal year start" do
    date = Current.org.next_fiscal_year.range.min
    Tenant.disconnect

    out, = capture_io { Rake::Task["organizations:next_fiscal_year"].invoke }

    assert_includes out, "-- #{date} --"
    assert_includes out, "Acme"
  ensure
    Tenant.connect("acme")
  end
end
