# frozen_string_literal: true

require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  test "depot_delivery_list_email" do
    depot = depots(:farm)
    depot.update!(emails: "respondent1@csa-admin.org, respondent2@csa-admin.org")

    mail = AdminMailer.with(
      depot: depot,
      baskets: Basket.all,
      delivery: deliveries(:monday_1)
    ).depot_delivery_list_email

    assert_equal "Delivery list of 1 April 2024 (Farm)", mail.subject
    assert_equal [ "respondent1@csa-admin.org", "respondent2@csa-admin.org" ], mail.to
    assert_equal "admin-depot-delivery-list", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.html_part.body
    assert_includes body, "Here is the list of members:"
    assert_includes body, "<strong>John Doe</strong>, Medium"
    assert_includes body, "See the attachments for more details, thank you."
    assert_not_includes body, "Manage my notifications"

    assert_equal 2, mail.attachments.size
    attachment1 = mail.attachments.first
    assert_equal "delivery-#1-20240401.xlsx", attachment1.filename
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml", attachment1.content_type
    attachment2 = mail.attachments.second
    assert_equal "sheets-delivery-#1-20240401.pdf", attachment2.filename
    assert_equal "application/pdf", attachment2.content_type
  end

  test "delivery_list_email" do
    delivery = deliveries(:monday_1)
    mail = AdminMailer.with(
      admin: admins(:ultra),
      delivery: delivery
    ).delivery_list_email

    assert_equal "Delivery list of 1 April 2024", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-delivery-list", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.html_part.body.to_s
    assert_includes body, "(XLSX)"
    assert_includes body, "(PDF)"
    assert_includes body, "Access the delivery page"
    assert_includes body, "https://admin.acme.test/deliveries/#{delivery.id}"
    assert_includes body, "Manage my notifications"

    assert_equal 2, mail.attachments.size
    attachment1 = mail.attachments.first
    assert_equal "delivery-#1-20240401.xlsx", attachment1.filename
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml", attachment1.content_type
    attachment2 = mail.attachments.second
    assert_equal "sheets-delivery-#1-20240401.pdf", attachment2.filename
    assert_equal "application/pdf", attachment2.content_type
  end

  test "invitation_email" do
    admin = Admin.new(
      name: "Bob",
      language: "en",
      email: "bob@csa-admin.org")

    mail = AdminMailer.with(
      admin: admin,
      action_url: "https://admin.acme.test"
    ).invitation_email

    assert_equal "Invitation to the Acme admin", mail.subject
    assert_equal [ "bob@csa-admin.org" ], mail.to
    assert_equal "admin-invitation", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Bob,"
    assert_includes body, "bob@csa-admin.org"
    assert_includes body, "Access the admin of Acme"
    assert_includes body, "https://admin.acme.test"
    assert_not_includes body, "Manage my notifications"
  end

  test "invoice_overpaid_email" do
    invoice = invoices(:annual_fee)

    mail = AdminMailer.with(
      admin: admins(:ultra),
      member: invoice.member,
      invoice: invoice
    ).invoice_overpaid_email

    assert_equal "Overpaid invoice ##{invoice.id}", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-invoice-overpaid", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Thibaud,"
    assert_includes body, "Overpaid invoice ##{invoice.id}"
    assert_includes body, "Martha"
    assert_includes body, "Access member page"
    assert_includes body, "https://admin.acme.test/members/#{invoice.member_id}"
    assert_includes body, "https://admin.acme.test/admins/#{admins(:ultra).id}/edit#notifications"
    assert_includes body, "Manage my notifications"
  end

  test "invoice_third_overdue_notice_email" do
    invoice = invoices(:annual_fee)

    mail = AdminMailer.with(
      admin: admins(:ultra),
      invoice: invoice
    ).invoice_third_overdue_notice_email

    assert_equal "Invoice ##{invoice.id}, 3rd reminder sent", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-invoice-third-overdue-notice", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Thibaud,"
    assert_includes body, "The 3rd reminder has just been sent for invoice ##{invoice.id}"
    assert_includes body, "Martha"
    assert_includes body, "Access member page"
    assert_includes body, "https://admin.acme.test/members/#{invoice.member_id}"
    assert_includes body, "https://admin.acme.test/admins/#{admins(:ultra).id}/edit#notifications"
    assert_includes body, "Manage my notifications"
  end

  test "payment_reversal_email" do
    payment = payments(:other_closed)

    mail = AdminMailer.with(
      admin: admins(:ultra),
      payment: payment,
      member: payment.member
    ).payment_reversal_email

    assert_equal "Payment reversal for invoice ##{payment.invoice_id}", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-payment-reversal", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Thibaud,"
    assert_includes body, "A payment for the invoice ##{payment.invoice_id} from <strong>#{payment.member.name}</strong> has been reversed, please verify."
    assert_includes body, "Access reversal payment page"
    assert_includes body, "https://admin.acme.test/payments/#{payment.id}"
    assert_includes body, "https://admin.acme.test/admins/#{admins(:ultra).id}/edit#notifications"
    assert_includes body, "Manage my notifications"
  end

  test "new_absence_email" do
    absence = absences(:jane_thursday_5)

    mail = AdminMailer.with(
      admin: admins(:ultra),
      member: absence.member,
      absence: absence
    ).new_absence_email

    assert_equal "New absence", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-absence-created", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Thibaud,"
    assert_includes body, "Jane"
    assert_includes body, "from 1 May 2024 to 7 May 2024."
    assert_includes body, "Member's note:<br/>\n  <i>Vacation</i>"
    assert_includes body, "Access the absence page"
    assert_includes body, "https://admin.acme.test/absences/#{absence.id}"
    assert_includes body, "https://admin.acme.test/admins/#{admins(:ultra).id}/edit#notifications"
    assert_includes body, "Manage my notifications"
  end

  test "new_activity_participation_email" do
    mail = AdminMailer.with(
      admin: admins(:ultra),
      activity_participation_ids: [ activity_participations(:jane_harvest).id ]
    ).new_activity_participation_email

    assert_equal "New participation in a ½ day", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-activity-participation-created", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Thibaud,"
    assert_includes body, "The member <strong>Jane Doe</strong> has registered for an activity"
    assert_includes body, "<strong>Date:</strong> Monday 1 July 2024"
    assert_includes body, "<strong>Schedule:</strong> 8:30-12:00"
    assert_includes body, "<strong>Activity:</strong> Help with the harvest"
    assert_includes body, "<strong>Description:</strong> Picking vegetables"
    assert_includes body, "<strong>Location:</strong> <a href=\"https://farm.example.com\" target=\"_blank\">Farm</a>"
    assert_includes body, "<strong>Participants:</strong> 1"
    assert_includes body, "<strong>Carpooling:</strong> +41 79 123 45 67 (La Chaux-de-Fonds)"
    assert_includes body, "Member's note:<br/>\n  <i>I will bring my own gloves</i>"
    assert_includes body, "Access the member's participation page"
    assert_includes body, "https://admin.acme.test/activity_participations?q%5Bmember_id_eq%5D=#{members(:jane).id}&scope=future"
    assert_includes body, "https://admin.acme.test/admins/#{admins(:ultra).id}/edit#notifications"
    assert_includes body, "Manage my notifications"
  end

  test "new_email_suppression_email" do
    email_suppression = OpenStruct.new(
      reason: "HardBounce",
      email: "john@doe.com",
      owners: [ members(:john) ]
    )

    mail = AdminMailer.with(
      admin: admins(:ultra),
      email_suppression: email_suppression
    ).new_email_suppression_email

    assert_equal "Email rejected (HardBounce)", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-email-suppression-created", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Thibaud,"
    assert_includes body, "Email rejected (HardBounce)</h1>\n<p>Hello Thibaud,</p>\n\n<p>The email <strong>john@doe.com</strong> was rejected during the last message delivery due to the following reason: <strong>HardBounce</strong>.</p>"
    assert_includes body, "Member: John Doe"
    assert_includes body, "https://admin.acme.test/members/#{members(:john).id}"
    assert_includes body, "https://admin.acme.test/admins/#{admins(:ultra).id}/edit#notifications"
    assert_includes body, "Manage my notifications"
  end

  test "new_registration_email" do
    mail = AdminMailer.with(
      admin: admins(:ultra),
      member: members(:john),
    ).new_registration_email

    assert_equal "New registration", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-member-created", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Thibaud,"
    assert_includes body, "John Doe"
    assert_includes body, "Access member page"
    assert_includes body, "https://admin.acme.test/members/#{members(:john).id}"
    assert_includes body, "https://admin.acme.test/admins/#{admins(:ultra).id}/edit#notifications"
    assert_includes body, "Manage my notifications"
  end

  test "memberships_renewal_pending_email" do
    mail = AdminMailer.with(
      admin: admins(:ultra),
      pending_memberships: [ memberships(:john), memberships(:jane) ],
      opened_memberships: [ memberships(:jane) ],
      pending_action_url: "https://admin.example.com/memberships/pending",
      opened_action_url: "https://admin.example.com/memberships/opened",
      action_url: "https://admin.example.com/memberships"
    ).memberships_renewal_pending_email

    assert_equal "⚠️ Membership(s) pending renewal!", mail.subject
    assert_equal [ "info@csa-admin.org" ], mail.to
    assert_equal "admin-memberships-renewal-pending", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body.to_s
    assert_includes body, "Hello Thibaud,"
    assert_includes body, "2 membership(s)</a>"
    assert_includes body, "https://admin.example.com/memberships/pending"
    assert_includes body, "1 open renewal request(s)</a>"
    assert_includes body, "https://admin.example.com/memberships/opened"
    assert_includes body, "Access memberships"
    assert_includes body, "https://admin.example.com/memberships"
    assert_includes body, "https://admin.acme.test/admins/#{admins(:ultra).id}/edit#notifications"
    assert_includes body, "Manage my notifications"
  end

  test "memberships_renewal_pending_email_pending_only" do
    mail = AdminMailer.with(
      admin: admins(:ultra),
      pending_memberships: [ memberships(:john), memberships(:jane) ],
      opened_memberships: [],
      pending_action_url: "https://admin.example.com/memberships/pending",
      opened_action_url: "https://admin.example.com/memberships/opened",
      action_url: "https://admin.example.com/memberships"
    ).memberships_renewal_pending_email

    assert_equal "⚠️ Membership(s) pending renewal!", mail.subject
    assert_includes mail.body.to_s, "2 membership(s)</a>"
    assert_includes mail.body.to_s, "https://admin.example.com/memberships/pending"
    assert_not_includes mail.body.to_s, "request(s)</a>"
    assert_not_includes mail.body.to_s, "https://admin.example.com/memberships.opened"
  end

  test "memberships_renewal_pending_email_opened_only" do
    mail = AdminMailer.with(
      admin: admins(:ultra),
      pending_memberships: [],
      opened_memberships: [ memberships(:john), memberships(:jane) ],
      pending_action_url: "https://admin.example.com/memberships/pending",
      opened_action_url: "https://admin.example.com/memberships/opened",
      action_url: "https://admin.example.com/memberships"
    ).memberships_renewal_pending_email

    assert_equal "⚠️ Membership(s) pending renewal!", mail.subject
    assert_not_includes mail.body.to_s, "2 membership(s)</a>"
    assert_not_includes mail.body.to_s, "https://admin.example.com/memberships/pending"
    assert_includes mail.body.to_s, "2 open renewal request(s)</a>"
    assert_includes mail.body.to_s, "https://admin.example.com/memberships/opened"
  end
end
