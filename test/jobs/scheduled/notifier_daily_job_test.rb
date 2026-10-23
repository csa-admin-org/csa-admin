# frozen_string_literal: true

require "test_helper"

class Scheduled::NotifierDailyJobTest < ActiveJob::TestCase
  test "staggers notification types one second apart" do
    freeze_time do
      perform_enqueued_jobs only: Scheduled::NotifierDailyJob do
        Scheduled::NotifierDailyJob.perform_later
      end

      jobs = enqueued_jobs.select { |job| job["job_class"] == "NotificationJob" }
      notifications = Scheduled::NotifierDailyJob::NOTIFICATIONS

      assert_equal notifications.size, jobs.size

      notifications.each_with_index do |notification, index|
        job = jobs[index]
        assert_equal notification.name, job["arguments"].first
        assert_in_delta index.seconds.from_now.to_f, job[:at].to_f, 0.001
      end
    end
  end
end
