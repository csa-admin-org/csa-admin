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
end
