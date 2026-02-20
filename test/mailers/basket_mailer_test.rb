# frozen_string_literal: true

require "test_helper"

class BasketMailerTest < ActionMailer::TestCase
  test "initial_email" do
    travel_to "2024-01-01"
    template = mail_templates(:basket_initial)
    membership = memberships(:john)
    basket = membership.baskets.first

    mail = BasketMailer.with(
      template: template,
      basket: basket,
    ).initial_email

    assert_equal "First basket!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "basket-initial", mail.tag
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "final_email" do
    travel_to "2024-01-01"
    template = mail_templates(:basket_final)
    membership = memberships(:john)
    basket = membership.baskets.last

    mail = BasketMailer.with(
      template: template,
      basket: basket,
    ).final_email

    assert_equal "Last basket!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "basket-final", mail.tag
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "first_email" do
    travel_to "2024-01-01"
    template = mail_templates(:basket_first)
    membership = memberships(:john)
    basket = membership.baskets.first

    mail = BasketMailer.with(
      template: template,
      basket: basket,
    ).first_email

    assert_equal "First basket of the year!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "basket-first", mail.tag
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "last_email" do
    travel_to "2024-01-01"
    template = mail_templates(:basket_last)
    membership = memberships(:john)
    basket = membership.baskets.last

    mail = BasketMailer.with(
      template: template,
      basket: basket,
    ).last_email

    assert_equal "Last basket of the year!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "basket-last", mail.tag
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "last_trial_email" do
    travel_to "2024-01-01"
    template = mail_templates(:basket_last_trial)
    membership = memberships(:john)
    basket = membership.baskets.first

    mail = BasketMailer.with(
      template: template,
      basket: basket,
    ).last_trial_email

    assert_equal "Last trial basket!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "basket-last-trial", mail.tag
    assert_includes mail.body.to_s, "Today is the last day of your trial period."
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "second_last_trial_email" do
    travel_to "2024-01-01"
    template = mail_templates(:basket_second_last_trial)
    membership = memberships(:john)
    basket = membership.baskets.first

    mail = BasketMailer.with(
      template: template,
      basket: basket,
    ).second_last_trial_email

    assert_equal "Second to last trial basket!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "basket-second-last-trial", mail.tag
    assert_includes mail.body.to_s, "This is your second to last trial basket."
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end
end
