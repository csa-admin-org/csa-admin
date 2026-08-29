# frozen_string_literal: true

require "test_helper"

class Scheduled::ChoresJobTest < ActiveJob::TestCase
  test "purges expired mail deliveries" do
    old_delivery = travel_to 13.months.ago do
      MailDelivery.deliver!(
        member: members(:john),
        mailable_type: "Invoice",
        action: "created")
    end

    Scheduled::ChoresJob.new.send(:purge_expired_mail_deliveries!)

    assert_not MailDelivery.exists?(old_delivery.id)
  end

  test "does not clear the shared queue shard" do
    source = File.read(Rails.root.join("app/jobs/scheduled/chores_job.rb"))

    assert_no_match(/SolidQueue/, source)
  end
end
