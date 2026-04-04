# frozen_string_literal: true

require "test_helper"

class BasketComplementMailerTest < ActionMailer::TestCase
  test "weekly_summary_email" do
    complement = basket_complements(:bread)
    complement.update!(emails: "supplier@example.com", language: "en")

    delivery1 = deliveries(:thursday_1)
    delivery2 = deliveries(:thursday_2)
    deliveries_counts = [
      { delivery: delivery1, count: 25 },
      { delivery: delivery2, count: 18 }
    ]

    mail = BasketComplementMailer.with(
      basket_complement: complement,
      deliveries_counts: deliveries_counts
    ).weekly_summary_email

    assert_equal "Weekly summary of Bread (week #{delivery1.date.cweek})", mail.subject
    assert_equal [ "supplier@example.com" ], mail.to
    assert_equal "basket-complement-weekly-summary", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.body
    assert_includes body, "Here are the counts of Bread for the upcoming week:"
    assert_includes body, "Thursday 4 April"
    assert_includes body, "25"
    assert_includes body, "Thursday 11 April"
    assert_includes body, "18"
    assert_includes body, "Total"
    assert_includes body, "43"
    assert_not_includes body, "Manage my notifications"

    assert_equal 0, mail.attachments.size
  end
end
