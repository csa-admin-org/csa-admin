# frozen_string_literal: true

require "test_helper"

class BasketComplementMailerTest < ActionMailer::TestCase
  test "delivery_count_email" do
    complement = basket_complements(:bread)
    complement.update!(emails: "supplier@example.com", language: "en")
    delivery = deliveries(:thursday_1)

    mail = BasketComplementMailer.with(
      basket_complement: complement,
      delivery: delivery,
      count: 25
    ).delivery_count_email

    assert_equal "Bread count for Thursday 4 April", mail.subject
    assert_equal [ "supplier@example.com" ], mail.to
    assert_equal "basket-complement-delivery-count", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body
    assert_includes body, "Here is the count of Bread needed for this delivery:"
    assert_includes body, "Delivery date"
    assert_includes body, "Thursday 4 April"
    assert_includes body, "Count"
    assert_includes body, "25"
    assert_not_includes body, "Total"
    assert_not_includes body, "Manage my notifications"

    assert_equal 0, mail.attachments.size
  end
end
