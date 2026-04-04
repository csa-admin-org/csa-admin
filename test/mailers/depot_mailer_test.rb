# frozen_string_literal: true

require "test_helper"

class DepotMailerTest < ActionMailer::TestCase
  test "delivery_list_email" do
    depot = depots(:farm)
    depot.update!(emails: "respondent1@csa-admin.org, respondent2@csa-admin.org")

    mail = DepotMailer.with(
      depot: depot,
      baskets: Basket.all,
      delivery: deliveries(:monday_1)
    ).delivery_list_email

    assert_equal "Delivery list of 1 April 2024 (Farm)", mail.subject
    assert_equal [ "respondent1@csa-admin.org", "respondent2@csa-admin.org" ], mail.to
    assert_equal "depot-delivery-list", mail.tag
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
end
