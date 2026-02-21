# frozen_string_literal: true

require "test_helper"

class MailDeliveryTest < ActiveSupport::TestCase
  # --- deliver! ---

  test "deliver! creates delivery with email children" do
    member = members(:john)
    invoice = invoices(:annual_fee)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_difference -> { MailDelivery::Email.count }, 1 do
        MailDelivery.deliver!(
          member: member,
          mailable: invoice,
          action: "created")
      end
    end

    delivery = MailDelivery.last
    assert_equal "Invoice", delivery.mailable_type
    assert_equal [ invoice.id ], delivery.mailable_ids
    assert_equal "created", delivery.action
    assert_equal member, delivery.member
    assert_equal "processing", delivery.state

    email = delivery.emails.first
    assert_equal "john@doe.com", email.email
    assert_equal "processing", email.state
  end

  test "deliver! creates one delivery per member with multiple email children" do
    member = members(:john)
    member.update!(emails: "john@doe.com, extra@doe.com")
    invoice = invoices(:annual_fee)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_difference -> { MailDelivery::Email.count }, 2 do
        MailDelivery.deliver!(
          member: member,
          mailable: invoice,
          action: "created",
          recipients: member.active_emails)
      end
    end

    delivery = MailDelivery.last
    assert_equal %w[extra@doe.com john@doe.com], delivery.emails.pluck(:email).sort
  end

  test "deliver! with explicit recipients" do
    member = members(:john)
    invoice = invoices(:annual_fee)

    MailDelivery.deliver!(
      member: member,
      mailable: invoice,
      action: "created",
      recipients: [ "billing@example.com" ])

    delivery = MailDelivery.last
    assert_equal 1, delivery.emails.count
    assert_equal "billing@example.com", delivery.emails.first.email
  end

  test "deliver! with draft creates no email children" do
    member = members(:john)
    newsletter = newsletters(:simple)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_no_difference -> { MailDelivery::Email.count } do
        MailDelivery.deliver!(
          member: member,
          mailable: newsletter,
          action: "newsletter",
          draft: true)
      end
    end

    delivery = MailDelivery.last
    assert_equal "draft", delivery.state
    assert_empty delivery.emails
  end

  test "deliver! for member with no email creates not_delivered trace" do
    member = members(:john)
    member.update!(emails: "")
    invoice = invoices(:annual_fee)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_no_difference -> { MailDelivery::Email.count } do
        MailDelivery.deliver!(
          member: member,
          mailable: invoice,
          action: "created")
      end
    end

    delivery = MailDelivery.last
    assert_equal "not_delivered", delivery.state
    assert_empty delivery.emails
  end

  test "deliver! derives mailable_type and mailable_ids from mailable" do
    member = members(:john)
    invoice = invoices(:annual_fee)

    MailDelivery.deliver!(member: member, mailable: invoice, action: "created")

    delivery = MailDelivery.last
    assert_equal "Invoice", delivery.mailable_type
    assert_equal [ invoice.id ], delivery.mailable_ids
  end

  test "deliver! accepts array of mailables" do
    member = members(:john)
    ap1 = activity_participations(:john_harvest)
    ap2 = activity_participations(:john_harvest)

    MailDelivery.deliver!(member: member, mailable: [ ap1, ap2 ], action: "reminder")

    delivery = MailDelivery.last
    assert_equal "ActivityParticipation", delivery.mailable_type
    assert_equal [ ap1.id, ap2.id ], delivery.mailable_ids
  end

  test "deliver! uses explicit mailable_type when mailable is nil" do
    member = members(:john)

    MailDelivery.deliver!(
      member: member,
      mailable: nil,
      mailable_type: "Absence",
      action: "included_reminder")

    delivery = MailDelivery.last
    assert_equal "Absence", delivery.mailable_type
    assert_empty delivery.mailable_ids
  end

  test "deliver! enqueues ProcessJob for each email" do
    member = members(:john)
    member.update!(emails: "john@doe.com, extra@doe.com")
    invoice = invoices(:annual_fee)

    assert_enqueued_jobs 2, only: MailDelivery::ProcessJob do
      MailDelivery.deliver!(
        member: member,
        mailable: invoice,
        action: "created",
        recipients: member.active_emails)
    end
  end

  test "deliver! draft does not enqueue ProcessJob" do
    member = members(:john)
    newsletter = newsletters(:simple)

    assert_no_enqueued_jobs(only: MailDelivery::ProcessJob) do
      MailDelivery.deliver!(
        member: member,
        mailable: newsletter,
        action: "newsletter",
        draft: true)
    end
  end

  # --- deliver! for newsletters ---

  test "deliver! creates newsletter delivery with email children" do
    newsletter = newsletters(:simple)
    member = members(:john)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_difference -> { MailDelivery::Email.count }, 1 do
        MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
      end
    end

    delivery = MailDelivery.last
    assert_equal "Newsletter", delivery.mailable_type
    assert_equal [ newsletter.id ], delivery.mailable_ids
    assert_equal "newsletter", delivery.action
    assert_equal member, delivery.member
    assert_equal "processing", delivery.state

    email = delivery.emails.first
    assert_equal "john@doe.com", email.email
    assert_equal "processing", email.state
  end

  test "deliver! creates one newsletter email per address" do
    newsletter = newsletters(:simple)
    member = members(:john)
    member.update!(emails: "john@bob.com, jojo@old.com")

    assert_difference -> { MailDelivery::Email.count }, 2 do
      MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
    end

    delivery = MailDelivery.last
    assert_equal %w[john@bob.com jojo@old.com], delivery.emails.pluck(:email).sort
  end

  test "deliver! with draft creates newsletter MailDelivery with no Email children" do
    newsletter = newsletters(:simple)
    member = members(:john)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_no_difference -> { MailDelivery::Email.count } do
        MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter", draft: true)
      end
    end

    delivery = MailDelivery.last
    assert_equal "draft", delivery.state
    assert_empty delivery.emails
  end

  test "deliver! newsletter draft does not enqueue ProcessJob" do
    newsletter = newsletters(:simple)
    member = members(:john)

    assert_no_enqueued_jobs(only: MailDelivery::ProcessJob) do
      MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter", draft: true)
    end
  end

  test "deliver! creates newsletter delivery with specific recipients" do
    newsletter = newsletters(:simple)
    member = members(:john)

    MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter", recipients: [ "specific@email.com" ])

    delivery = MailDelivery.last
    assert_equal 1, delivery.emails.count
    assert_equal "specific@email.com", delivery.emails.first.email
  end

  test "deliver! keeps newsletter trace for member without email" do
    newsletter = newsletters(:simple)
    member = members(:john)
    member.update!(emails: "")

    assert_difference -> { MailDelivery.count }, 1 do
      assert_no_difference -> { MailDelivery::Email.count } do
        MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
      end
    end

    delivery = MailDelivery.last
    assert_equal "not_delivered", delivery.state
    assert_empty delivery.emails
  end

  # --- State recomputation ---

  test "recompute_state! sets delivered when all emails delivered" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    delivery.emails.first.delivered!(at: Time.current)

    assert_equal "delivered", delivery.reload.state
  end

  test "recompute_state! sets not_delivered when all emails bounced" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    delivery.emails.first.bounced!(at: Time.current)

    assert_equal "not_delivered", delivery.reload.state
  end

  test "recompute_state! sets not_delivered when all emails suppressed" do
    member = members(:john)
    member.update!(emails: "suppressed@test.com")
    suppress_email("suppressed@test.com", stream_id: "broadcast")

    newsletter = newsletters(:simple)
    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
    end

    delivery = MailDelivery.last
    assert_equal "not_delivered", delivery.state
  end

  test "recompute_state! sets partially_delivered with mixed states" do
    member = members(:john)
    member.update!(emails: "a@test.com, b@test.com")

    newsletter = newsletters(:simple)
    MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")

    delivery = MailDelivery.last
    emails = delivery.emails.order(:email)

    emails.first.delivered!(at: Time.current)
    emails.last.bounced!(at: Time.current)

    assert_equal "partially_delivered", delivery.reload.state
  end

  test "recompute_state! skips draft deliveries" do
    newsletter = newsletters(:simple)
    member = members(:john)

    delivery = MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter", draft: true)
    delivery.recompute_state!

    assert_equal "draft", delivery.state
  end

  # --- Scopes ---

  test "newsletters scope returns only newsletter deliveries" do
    member = members(:john)
    newsletter = newsletters(:simple)

    assert_difference -> { MailDelivery.newsletters.count }, 1 do
      MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
    end

    assert_no_difference -> { MailDelivery.newsletters.count } do
      MailDelivery.deliver!(
        member: member, mailable: invoices(:annual_fee), action: "created")
    end
  end

  test "templates scope returns only template deliveries" do
    member = members(:john)
    newsletter = newsletters(:simple)

    assert_no_difference -> { MailDelivery.mail_templates.count } do
      MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
    end

    assert_difference -> { MailDelivery.mail_templates.count }, 1 do
      MailDelivery.deliver!(
        member: member, mailable: invoices(:annual_fee), action: "created")
    end

    assert_equal "Invoice", MailDelivery.mail_templates.order(:id).last.mailable_type
  end

  test "state scopes filter correctly" do
    member = members(:john)
    newsletter = newsletters(:simple)

    # Draft newsletter delivery
    draft_delivery = MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter", draft: true)
    assert_includes MailDelivery.draft, draft_delivery

    # Processing template delivery
    processing_delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    assert_includes MailDelivery.processing, processing_delivery

    # Delivered
    processing_delivery.emails.first.delivered!(at: Time.current)
    assert_includes MailDelivery.delivered, processing_delivery
  end

  test "for_mailable scope finds deliveries by mailable type and ID" do
    member = members(:john)
    invoice = invoices(:annual_fee)

    delivery = MailDelivery.deliver!(
      member: member, mailable: invoice, action: "created")

    assert_includes MailDelivery.for_mailable(invoice), delivery
  end

  test "for_mailable scope does not match different mailable types" do
    member = members(:john)

    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_not_includes MailDelivery.for_mailable(members(:john)), delivery
  end

  test "for_mailable scope works with activity participation group IDs" do
    member = members(:john)
    ap = activity_participations(:john_harvest)

    delivery = MailDelivery.deliver!(
      member: member, mailable: [ ap ], action: "reminder")

    assert_includes MailDelivery.for_mailable(ap), delivery
  end

  test "newsletter_id_eq ransack scope filters by newsletter ID" do
    member = members(:john)
    newsletter = newsletters(:simple)

    delivery = MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")

    assert_includes MailDelivery.newsletter_id_eq(newsletter.id), delivery
    assert_not_includes MailDelivery.newsletter_id_eq(newsletters(:sent).id), delivery
  end

  test "mail_template_id_eq ransack scope filters by mail_tempate id" do
    member = members(:john)
    invoice_created = mail_templates(:invoice_created)
    invoice_cancelled = mail_templates(:invoice_cancelled)

    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_includes MailDelivery.mail_template_id_eq(invoice_created.id), delivery
    assert_not_includes MailDelivery.mail_template_id_eq(invoice_cancelled.id), delivery
  end

  # --- Polymorphic helpers ---

  test "newsletter returns the Newsletter for newsletter deliveries" do
    newsletter = newsletters(:simple)
    member = members(:john)

    delivery = MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
    assert_equal newsletter, delivery.newsletter
  end

  test "newsletter returns nil for template deliveries" do
    member = members(:john)

    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_nil delivery.newsletter
  end

  test "newsletter? returns true for newsletter deliveries" do
    newsletter = newsletters(:simple)
    member = members(:john)

    delivery = MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
    assert delivery.newsletter?
  end

  test "newsletter? returns false for template deliveries" do
    member = members(:john)

    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_not delivery.newsletter?
  end

  test "source returns the Newsletter for newsletter deliveries" do
    newsletter = newsletters(:simple)
    member = members(:john)

    delivery = MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
    assert_equal newsletter, delivery.source
  end

  test "source returns the MailTemplate for template deliveries" do
    template = MailTemplate.find_or_create_by!(title: "invoice_created")
    member = members(:john)

    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_equal template, delivery.source
  end

  # --- Cascading destroy ---

  test "destroying delivery cascades to emails" do
    member = members(:john)

    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_equal 1, delivery.emails.count

    assert_difference -> { MailDelivery::Email.count }, -1 do
      delivery.destroy!
    end
  end
end
