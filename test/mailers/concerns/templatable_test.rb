# frozen_string_literal: true

require "test_helper"

class TemplatableTest < ActionMailer::TestCase
  # --- MailDelivery tracking via MailTemplate.deliver ---

  test "deliver creates MailDelivery and MailDelivery::Email records" do
    template = mail_templates(:member_activated)
    template.update!(active: true)
    member = members(:jane)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_difference -> { MailDelivery::Email.count }, 1 do
        MailTemplate.deliver(:member_activated, member: member)
      end
    end

    delivery = MailDelivery.last
    assert_equal "Member", delivery.mailable_type
    assert_equal [ member.id ], delivery.mailable_ids
    assert_equal "activated", delivery.action
    assert_equal member, delivery.member
    assert_equal "processing", delivery.state
  end

  test "deliver stores rendered subject and full HTML content via ProcessJob" do
    travel_to "2024-01-01"
    template = mail_templates(:member_activated)
    template.update!(active: true)
    member = members(:jane)

    perform_enqueued_jobs do
      MailTemplate.deliver(:member_activated, member: member)
    end

    delivery = MailDelivery.last
    assert_equal "Welcome!", delivery.subject
    assert_includes delivery.content, "Your membership is now active."
    assert_includes delivery.content, "<html"
  end

  test "deliver creates MailDelivery::Email with member active_emails" do
    template = mail_templates(:member_validated)
    template.update!(active: true)
    member = members(:john)

    MailTemplate.deliver(:member_validated, member: member)

    delivery = MailDelivery.last
    email_record = delivery.emails.first
    assert_equal "john@doe.com", email_record.email
    assert_equal "processing", email_record.state
  end

  # --- One MailDelivery per member with multiple Email children ---

  test "deliver creates one MailDelivery with multiple Email children for multi-email member" do
    template = mail_templates(:member_validated)
    template.update!(active: true)
    member = members(:john)
    member.update!(emails: "john@doe.com, extra@doe.com")

    assert_difference -> { MailDelivery.count }, 1 do
      assert_difference -> { MailDelivery::Email.count }, 2 do
        MailTemplate.deliver(:member_validated, member: member)
      end
    end

    delivery = MailDelivery.where(member: member, mailable_type: "Member", action: "validated").last
    assert_equal %w[extra@doe.com john@doe.com], delivery.emails.pluck(:email).sort
    assert_equal "processing", delivery.state
  end

  test "deliver sends one email per recipient via ProcessJob" do
    template = mail_templates(:member_validated)
    template.update!(active: true)
    member = members(:john)
    member.update!(emails: "john@doe.com, extra@doe.com")

    assert_difference -> { ActionMailer::Base.deliveries.count }, 2 do
      perform_enqueued_jobs do
        MailTemplate.deliver(:member_validated, member: member)
      end
    end

    recipients = ActionMailer::Base.deliveries.last(2).flat_map(&:to).sort
    assert_equal %w[extra@doe.com john@doe.com], recipients
  end

  test "single mailer call sends to exactly one recipient" do
    template = mail_templates(:member_validated)
    member = members(:john)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      MemberMailer.with(template: template, member: member, to: "john@doe.com").validated_email.deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ "john@doe.com" ], email.to
  end

  test "direct mailer call does not create MailDelivery records" do
    template = mail_templates(:member_validated)
    member = members(:john)

    assert_no_difference -> { MailDelivery.count } do
      MemberMailer.with(template: template, member: member, to: "john@doe.com").validated_email.deliver_now
    end
  end

  test "deliver enqueues ProcessJob for each email" do
    template = mail_templates(:member_validated)
    template.update!(active: true)
    member = members(:john)

    assert_enqueued_jobs 1, only: MailDelivery::ProcessJob do
      MailTemplate.deliver(:member_validated, member: member)
    end
  end

  test "each recipient gets its own Email child on a single MailDelivery" do
    template = mail_templates(:member_validated)
    template.update!(active: true)
    member = members(:john)
    member.update!(emails: "john@doe.com, extra@doe.com")

    perform_enqueued_jobs do
      MailTemplate.deliver(:member_validated, member: member)
    end

    delivery = MailDelivery.where(member: member, mailable_type: "Member", action: "validated").last
    assert_equal 2, delivery.emails.count
    assert_equal %w[extra@doe.com john@doe.com], delivery.emails.pluck(:email).sort
  end

  # --- Invoice recipients (billing_emails) ---

  test "deliver uses billing_emails for invoice templates" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    template.update!(active: true)
    invoice = invoices(:annual_fee)
    invoice.member.update!(billing_email: "billing@accounting.com")

    MailTemplate.deliver(:invoice_created, invoice: invoice)

    delivery = MailDelivery.last
    assert_equal "Invoice", delivery.mailable_type
    assert_equal [ invoice.id ], delivery.mailable_ids
    assert_equal "created", delivery.action
    email_record = delivery.emails.first
    assert_equal "billing@accounting.com", email_record.email
  end

  test "deliver resolves invoice billing_emails via ProcessJob" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    template.update!(active: true)
    invoice = invoices(:annual_fee)
    invoice.member.update!(billing_email: "billing@accounting.com")

    assert_difference -> { MailDelivery.count }, 1 do
      perform_enqueued_jobs do
        MailTemplate.deliver(:invoice_created, invoice: invoice)
      end
    end

    delivery = MailDelivery.last
    assert_equal "billing@accounting.com", delivery.emails.first.email
  end

  # --- Other mailer templates create MailDelivery via deliver ---

  test "deliver creates MailDelivery for absence_created" do
    template = mail_templates(:absence_created)
    template.update!(active: true)
    absence = absences(:jane_thursday_5)

    assert_difference -> { MailDelivery.count }, 1 do
      MailTemplate.deliver(:absence_created, absence: absence)
    end

    delivery = MailDelivery.last
    assert_equal "Absence", delivery.mailable_type
    assert_equal [ absence.id ], delivery.mailable_ids
    assert_equal "created", delivery.action
    assert_equal absence.member, delivery.member
  end

  test "deliver creates MailDelivery for membership_renewal" do
    template = mail_templates(:membership_renewal)
    template.update!(active: true)
    membership = memberships(:jane)

    assert_difference -> { MailDelivery.count }, 1 do
      MailTemplate.deliver(:membership_renewal, membership: membership)
    end

    delivery = MailDelivery.last
    assert_equal "Membership", delivery.mailable_type
    assert_equal [ membership.id ], delivery.mailable_ids
    assert_equal "renewal", delivery.action
    assert_equal membership.member, delivery.member
  end

  # --- Email suppression handling ---

  test "outbound-suppressed email is excluded by active_emails" do
    template = mail_templates(:member_validated)
    template.update!(active: true)
    member = members(:john)
    member.update!(emails: "john@doe.com, extra@doe.com")
    suppress_email("extra@doe.com", stream_id: "outbound")

    perform_enqueued_jobs do
      MailTemplate.deliver(:member_validated, member: member)
    end

    # active_emails pre-filters outbound suppressions, so only 1 email child
    delivery = MailDelivery.where(member: member, mailable_type: "Member", action: "validated").last
    assert_equal 1, delivery.emails.count
    assert_equal "john@doe.com", delivery.emails.first.email
    assert delivery.emails.first.processing?
  end

  test "broadcast-suppressed email is marked as suppressed via process!" do
    template = mail_templates(:member_validated)
    template.update!(active: true)
    member = members(:john)
    member.update!(emails: "john@doe.com, extra@doe.com")
    suppression = suppress_email("extra@doe.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailTemplate.deliver(:member_validated, member: member)
    end

    # broadcast suppressions are NOT filtered by active_emails (only outbound are),
    # so both emails are in one delivery; the broadcast-suppressed one is marked suppressed
    delivery = MailDelivery.where(member: member, mailable_type: "Member", action: "validated").last
    assert_equal 2, delivery.emails.count

    suppressed_email = delivery.emails.find_by(email: "extra@doe.com")
    assert suppressed_email.suppressed?
    assert_equal [ suppression.id ], suppressed_email.email_suppression_ids
    assert_equal %w[HardBounce], suppressed_email.email_suppression_reasons

    clean_email = delivery.emails.find_by(email: "john@doe.com")
    assert clean_email.processing?
    assert_empty clean_email.email_suppression_ids
  end

  # --- Non-tracked mailers do NOT create MailDelivery records ---

  test "AdminMailer does NOT create MailDelivery records" do
    assert_no_difference -> { MailDelivery.count } do
      AdminMailer.with(
        admin: admins(:ultra),
        member: members(:john)
      ).new_registration_email.deliver_now
    end
  end

  test "SessionMailer does NOT create MailDelivery records" do
    session = Session.new(
      member: Member.new(language: "en"),
      email: "test@example.com")

    assert_no_difference -> { MailDelivery.count } do
      SessionMailer.with(
        session: session,
        session_url: "https://example.com/session/token"
      ).new_member_session_email.deliver_now
    end
  end

  test "NewsletterMailer does NOT create template MailDelivery via template_mail" do
    newsletter = newsletters(:simple)

    perform_enqueued_jobs do
      newsletter.send!
    end

    # Newsletter sending creates Newsletter-type MailDelivery records (via create_deliveries!),
    # but Templatable must NOT create template-type records.
    assert MailDelivery.newsletters.any?, "Expected newsletter MailDelivery records"
    assert_empty MailDelivery.mail_templates, "Expected no template MailDelivery records from newsletter sending"
  end

  # --- No-email member creates not_delivered trace ---

  test "deliver creates not_delivered trace for member with no email" do
    template = mail_templates(:member_validated)
    template.update!(active: true)
    member = members(:john)
    member.update!(emails: "")

    assert_difference -> { MailDelivery.count }, 1 do
      assert_no_difference -> { MailDelivery::Email.count } do
        MailTemplate.deliver(:member_validated, member: member)
      end
    end

    delivery = MailDelivery.last
    assert_equal "not_delivered", delivery.state
    assert_empty delivery.emails
  end

  # --- Delivery behavior is preserved ---

  test "template email is still delivered via ActionMailer" do
    template = mail_templates(:member_validated)
    member = members(:john)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      MemberMailer.with(template: template, member: member, to: "john@doe.com").validated_email.deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ "john@doe.com" ], email.to
    assert_equal "outbound", email[:message_stream].to_s
  end

  test "template email preserves attachments" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)

    InvoiceMailer.with(template: template, invoice: invoice, to: invoice.member.billing_emails.first).created_email.deliver_now

    email = ActionMailer::Base.deliveries.last
    assert email.attachments.any?, "Expected email to have attachments"
    assert_equal "application/pdf", email.attachments.first.content_type
  end

  test "deliver creates MailDelivery and ProcessJob delivers the email" do
    template = mail_templates(:member_validated)
    member = members(:john)

    # Ensure the template is active
    template.update!(active: true)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
        perform_enqueued_jobs do
          MailTemplate.deliver(:member_validated, member: member)
        end
      end
    end

    delivery = MailDelivery.last
    assert_equal "Member", delivery.mailable_type
    assert_equal [ member.id ], delivery.mailable_ids
    assert_equal "validated", delivery.action
    assert_equal member, delivery.member
  end

  # --- recipients_for ---

  test "recipients_for returns active_emails for non-invoice templates" do
    template = mail_templates(:member_validated)
    member = members(:john)
    member.update!(emails: "john@doe.com, extra@doe.com")

    assert_equal %w[extra@doe.com john@doe.com], template.recipients_for(member).sort
  end

  test "recipients_for returns billing_emails for invoice templates" do
    template = mail_templates(:invoice_created)
    member = invoices(:annual_fee).member
    member.update!(billing_email: "billing@co.com")

    assert_equal [ "billing@co.com" ], template.recipients_for(member)
  end

  test "recipients_for returns nil for member with no emails" do
    template = mail_templates(:member_validated)
    member = members(:john)
    member.update!(emails: "")

    assert_nil template.recipients_for(member)
  end
end
