# frozen_string_literal: true

require "test_helper"

class Scheduled::MailDeliveriesPurgeJobTest < ActiveJob::TestCase
  test "performs without error" do
    assert_nothing_raised do
      Scheduled::MailDeliveriesPurgeJob.perform_now
    end
  end
end
