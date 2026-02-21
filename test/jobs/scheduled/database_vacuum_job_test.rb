# frozen_string_literal: true

require "test_helper"

class Scheduled::DatabaseVacuumJobTest < ActiveJob::TestCase
  test "performs without error" do
    assert_nothing_raised do
      Scheduled::DatabaseVacuumJob.perform_now
    end
  end
end
