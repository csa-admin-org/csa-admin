# frozen_string_literal: true

require "test_helper"

class Scheduled::DatabaseVacuumJobTest < ActiveJob::TestCase
  test "limits concurrency globally" do
    job = Scheduled::DatabaseVacuumJob.new

    assert_equal 1, Scheduled::DatabaseVacuumJob.concurrency_limit
    assert_equal "Scheduled::DatabaseVacuumJob/database-vacuum", job.concurrency_key
  end

  test "performs without error" do
    assert_nothing_raised do
      Scheduled::DatabaseVacuumJob.perform_now
    end
  end
end
