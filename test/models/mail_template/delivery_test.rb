# frozen_string_literal: true

require "test_helper"

class MailTemplate::DeliveryTest < ActiveSupport::TestCase
  test "deliveries_with_missing_emails returns deliveries with new member emails" do
    template = mail_templates(:invoice_created)
    member = members(:john)
    invoice = invoices(:annual_fee)

    MailDelivery.deliver!(
      member: member, mailable: invoice, action: "created")

    assert_empty template.deliveries_with_missing_emails

    member.update!(emails: "john@doe.com, john@new.com")

    deliveries = template.deliveries_with_missing_emails
    assert_equal 1, deliveries.size
    assert_equal member, deliveries.first.member
    assert_equal %w[john@new.com], deliveries.first.missing_emails
  end

  test "deliveries_with_missing_emails ignores deliveries outside allowed period" do
    template = mail_templates(:invoice_created)
    member = members(:john)
    invoice = invoices(:annual_fee)

    travel_to 2.weeks.ago do
      MailDelivery.deliver!(
        member: member, mailable: invoice, action: "created")
    end

    member.update!(emails: "john@doe.com, john@new.com")

    assert_empty template.deliveries_with_missing_emails
  end

  test "deliveries_with_missing_emails ignores draft deliveries" do
    template = mail_templates(:invoice_created)
    member = members(:john)

    MailDelivery.deliver!(
      member: member,
      mailable: nil,
      mailable_type: "Invoice",
      action: "created",
      draft: true)

    member.update!(emails: "john@doe.com, john@new.com")

    assert_empty template.deliveries_with_missing_emails
  end

  test "deliveries_with_missing_emails returns deliveries across multiple members" do
    template = mail_templates(:invoice_created)
    john = members(:john)
    jane = members(:jane)
    invoice = invoices(:annual_fee)

    MailDelivery.deliver!(
      member: john, mailable: invoice, action: "created")
    MailDelivery.deliver!(
      member: jane, mailable: invoice, action: "created")

    john.update!(emails: "john@doe.com, john@new.com")
    jane.update!(emails: "jane@doe.com, jane@new.com")

    deliveries = template.deliveries_with_missing_emails
    assert_equal 2, deliveries.size
    missing = deliveries.flat_map(&:missing_emails).sort
    assert_equal %w[jane@new.com john@new.com], missing
  end

  test "deliveries_with_missing_emails skips deliveries without missing emails" do
    template = mail_templates(:invoice_created)
    john = members(:john)
    jane = members(:jane)
    invoice = invoices(:annual_fee)

    # Two deliveries, only one member changes email
    MailDelivery.deliver!(
      member: john, mailable: invoice, action: "created")
    MailDelivery.deliver!(
      member: jane, mailable: invoice, action: "created")

    john.update!(emails: "john@doe.com, john@new.com")

    deliveries = template.deliveries_with_missing_emails
    assert_equal 1, deliveries.size
    assert_equal john, deliveries.first.member
  end

  test "show_missing_delivery_emails? is true when deliveries have missing emails" do
    template = mail_templates(:invoice_created)
    member = members(:john)
    invoice = invoices(:annual_fee)

    MailDelivery.deliver!(
      member: member, mailable: invoice, action: "created")

    assert_not template.show_missing_delivery_emails?

    member.update!(emails: "john@doe.com, john@new.com")

    assert template.show_missing_delivery_emails?
  end
end
