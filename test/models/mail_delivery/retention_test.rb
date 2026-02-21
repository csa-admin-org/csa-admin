# frozen_string_literal: true

require "test_helper"

class MailDelivery::RetentionTest < ActiveSupport::TestCase
  test "purge_expired! deletes deliveries older than retention period" do
    member = members(:john)

    old_delivery = travel_to 13.months.ago do
      MailDelivery.deliver!(
        member: member, mailable_type: "Invoice", action: "created")
    end

    assert MailDelivery.expired.exists?(old_delivery.id)

    MailDelivery.purge_expired!

    assert_not MailDelivery.exists?(old_delivery.id)
  end

  test "purge_expired! deletes email children of purged deliveries" do
    member = members(:john)

    old_delivery = travel_to 13.months.ago do
      MailDelivery.deliver!(
        member: member, mailable_type: "Invoice", action: "created")
    end

    email_ids = old_delivery.emails.pluck(:id)
    assert email_ids.any?

    MailDelivery.purge_expired!

    assert_empty MailDelivery::Email.where(id: email_ids)
  end

  test "purge_expired! preserves deliveries within retention period" do
    member = members(:john)

    recent_delivery = travel_to 11.months.ago do
      MailDelivery.deliver!(
        member: member, mailable_type: "Invoice", action: "created")
    end

    MailDelivery.purge_expired!

    assert MailDelivery.exists?(recent_delivery.id)
    assert recent_delivery.emails.any?
  end

  test "purge_expired! only deletes expired deliveries" do
    member = members(:john)

    old_delivery = travel_to 2.years.ago do
      MailDelivery.deliver!(
        member: member, mailable_type: "Invoice", action: "created")
    end

    recent_delivery = MailDelivery.deliver!(
      member: member, mailable_type: "Invoice", action: "created")

    MailDelivery.purge_expired!

    assert_not MailDelivery.exists?(old_delivery.id)
    assert MailDelivery.exists?(recent_delivery.id)
  end
end
