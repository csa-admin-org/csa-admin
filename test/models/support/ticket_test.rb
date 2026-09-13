# frozen_string_literal: true

require "test_helper"

class Support::TicketTest < ActiveSupport::TestCase
  test "invalid priority is a validation error instead of ArgumentError" do
    ticket = Support::Ticket.new(
      priority: "2",
      subject: "Test",
      content: "Test",
      admin: admins(:external))

    assert_not ticket.valid?
    assert_includes ticket.errors[:priority], I18n.t("errors.messages.inclusion")
  end

  test "priority accepts enum names" do
    ticket = Support::Ticket.new(
      subject: "Test",
      content: "Test",
      admin: admins(:external))

    ticket.priority = "high"
    assert ticket.high?
    assert ticket.valid?
  end

  test "subject_decorated" do
    ticket = Support::Ticket.new(
      priority: :normal,
      subject: "Subject")

    assert_equal "🛟 Subject", ticket.subject_decorated

    ticket.priority = :medium
    assert_equal "🛟❗️ Subject", ticket.subject_decorated

    ticket.priority = :high
    assert_equal "🛟‼️ Subject", ticket.subject_decorated
  end

  test "subject_with_priority appends medium and high marks" do
    ticket = Support::Ticket.new(priority: :normal, subject: "Subject")
    assert_equal "Subject", ticket.subject_with_priority

    ticket.priority = :medium
    assert_equal "Subject ❗️", ticket.subject_with_priority

    ticket.priority = :high
    assert_equal "Subject ‼️", ticket.subject_with_priority
  end

  test "display_title is the subject with priority mark" do
    ticket = Support::Ticket.new(id: 3, priority: :high, subject: "Subject")
    assert_equal "Subject ‼️", ticket.display_title
  end

  test "to_param is the token" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))
    assert_equal ticket.token, ticket.to_param
  end

  test "state follows last message author" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))
    assert_equal "waiting", ticket.state

    ticket.messages.create!(author: "support", body: "Answer", via: :app)
    assert_equal "replied", ticket.reload.state
  end

  test "mark_as_replied! moves a waiting ticket to replied" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))
    at = ticket.last_message.created_at

    ticket.mark_as_replied!(at: at)

    assert_equal "replied", ticket.reload.state
    assert ticket.marked_as_replied?
    assert_equal at.to_i, ticket.replied_at.to_i
    assert_equal at.to_i, ticket.last_activity_at.to_i
    assert_includes Support::Ticket.replied, ticket
    assert_not_includes Support::Ticket.waiting, ticket
  end

  test "last_activity_at uses replied_at when later than the last message" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))

    travel 1.hour do
      ticket.mark_as_replied!
    end

    assert_equal ticket.reload.replied_at.to_i, ticket.last_activity_at.to_i
    assert ticket.last_activity_at > ticket.last_message.created_at
  end

  test "a later message bumps last_activity_at" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))
    opened_at = ticket.last_activity_at

    travel 1.hour do
      message = ticket.messages.build(author: "support", body: "Answer", via: :app)
      message.skip_notify = true
      message.save!
    end

    assert ticket.reload.last_activity_at > opened_at
    assert_equal ticket.last_message.created_at.to_i, ticket.last_activity_at.to_i
  end

  test "a later admin message after mark_as_replied! returns the ticket to waiting" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))
    ticket.mark_as_replied!(at: 1.day.ago)
    message = ticket.messages.build(author: "admin", admin: admins(:external), body: "Phone follow-up")
    message.skip_notify = true
    message.save!

    assert_equal "waiting", ticket.reload.state
    assert_not ticket.marked_as_replied?
    assert_includes Support::Ticket.waiting, ticket
    assert_not_includes Support::Ticket.replied, ticket
  end

  test "last_activity_at ignores ticket metadata updates" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))
    opened_at = ticket.messages.first.created_at

    travel 1.hour do
      ticket.update!(subject: "Renamed")
    end

    assert_equal opened_at.to_i, ticket.reload.last_activity_at.to_i
    assert_not_equal ticket.updated_at.to_i, ticket.last_activity_at.to_i
  end

  test "context_path keeps the path of an admin URL" do
    ticket = Support::Ticket.new(context: "https://admin.ragedevert.ch/members/870")
    assert_equal "/members/870", ticket.context_path
  end

  test "assigns an 8 hex token on create" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Test", content: "Test", admin: admins(:external))

    assert_match(/\A[0-9a-f]{8}\z/, ticket.token)
  end

  test "copies content into the first message" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Test", content: "Hello there", admin: admins(:external))

    assert_equal 1, ticket.messages.count
    message = ticket.messages.first
    assert_equal "Hello there", message.body
    assert_equal "admin", message.author
    assert_equal admins(:external), message.admin
  end

  test "enqueues ping email on creation" do
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
        Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test", admin: admins(:external))
      end
    end
  end

  test "enqueues webhook job on creation when URL is set" do
    Support::Ticket.stub(:webhook_url, "https://webhook.example/support") do
      assert_enqueued_jobs 1, only: Support::MessageNotifyJob do
        Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test", admin: admins(:external))
      end
    end
  end

  test "does not enqueue webhook job when URL is blank" do
    Support::Ticket.stub(:webhook_url, nil) do
      assert_no_enqueued_jobs only: Support::MessageNotifyJob do
        Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test", admin: admins(:external))
      end
    end
  end

  test "webhook credentials come from Rails credentials" do
    Rails.application.credentials.stub(:dig, ->(*keys) {
      case keys
      when [ :support, :ticket_webhook, :url ] then "https://webhook.example/support"
      when [ :support, :ticket_webhook, :authorization ] then "Bearer secret"
      end
    }) do
      assert_equal "https://webhook.example/support", Support::Ticket.webhook_url
      assert_equal "Bearer secret", Support::Ticket.webhook_authorization
    end
  end

  test "webhook authorization prefixes Bearer when missing" do
    Rails.application.credentials.stub(:dig, ->(*keys) {
      "sender-key" if keys == [ :support, :ticket_webhook, :authorization ]
    }) do
      assert_equal "Bearer sender-key", Support::Ticket.webhook_authorization
    end
  end

  test "ping_address is SUPPORT_EMAIL for every priority" do
    ticket = Support::Ticket.new(priority: :high)
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      assert_equal "support@csa-admin.org", ticket.ping_address

      ticket.priority = :normal
      assert_equal "support@csa-admin.org", ticket.ping_address
    end
  end

  test "ping_from is a stable priority mailbox on the inbound domain" do
    ticket = Support::Ticket.new(priority: :high)
    assert_equal "\"CSA Admin 🛟‼️\" <high@support.csa-admin.org>", ticket.ping_from

    ticket.priority = :medium
    assert_equal "\"CSA Admin 🛟❗️\" <medium@support.csa-admin.org>", ticket.ping_from

    ticket.priority = :normal
    assert_equal "\"CSA Admin 🛟\" <normal@support.csa-admin.org>", ticket.ping_from
  end

  test "ping_address is nil without SUPPORT_EMAIL" do
    ticket = Support::Ticket.new(priority: :high)
    with_env("SUPPORT_EMAIL" => nil) do
      assert_nil ticket.ping_address
    end
  end

  test "waiting and replied scopes follow last message author" do
    waiting = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))
    replied = Support::Ticket.create!(
      priority: :normal, subject: "Done", content: "Hello", admin: admins(:external))
    replied.messages.create!(author: "support", body: "Answer", via: :app)

    assert_includes Support::Ticket.waiting, waiting
    assert_not_includes Support::Ticket.waiting, replied
    assert_includes Support::Ticket.replied, replied
    assert_not_includes Support::Ticket.replied, waiting
  end

  test "ordered_by_last_activity uses replied_at when later than the last message" do
    older = Support::Ticket.create!(
      priority: :normal, subject: "Older", content: "Hello", admin: admins(:external))
    newer = Support::Ticket.create!(
      priority: :normal, subject: "Newer", content: "Hello", admin: admins(:external))
    older.mark_as_replied!(at: 1.hour.from_now)

    assert_equal [ older, newer ].map(&:id), Support::Ticket.ordered_by_last_activity.where(id: [ older.id, newer.id ]).map(&:id)
  end

  test "last_activity_at ransack filter ignores ticket metadata updates" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Wait", content: "Hello", admin: admins(:external))
    opened_on = ticket.last_activity_at.to_date

    travel 2.days do
      ticket.update!(subject: "Renamed")
    end

    assert_includes Support::Ticket.ransack(last_activity_at_gteq: opened_on, last_activity_at_lteq: opened_on).result, ticket
    assert_empty Support::Ticket.ransack(last_activity_at_gteq: opened_on + 1.day).result.where(id: ticket.id)
  end

  test "text_cont matches subject and message body" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Shop checkout", content: "Opening", admin: admins(:external))
    ticket.messages.create!(author: "admin", admin: admins(:external), body: "The cart is stuck")

    assert_includes Support::Ticket.text_cont("checkout"), ticket
    assert_includes Support::Ticket.text_cont("cart"), ticket
    assert_empty Support::Ticket.text_cont("unrelated")
  end

  test "participants include requester and later admin authors" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Test", content: "Hello", admin: admins(:external))
    ticket.messages.create!(author: "admin", admin: admins(:super), body: "Jane follows up")

    assert_equal [ admins(:external), admins(:super) ].map(&:id).sort,
      ticket.participants.map(&:id).sort
  end

  test "wrap_emails_for excludes the hop author" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Test", content: "Hello", admin: admins(:external))
    jane = ticket.messages.create!(author: "admin", admin: admins(:super), body: "Jane")

    assert_equal [ admins(:external).email ], ticket.wrap_emails_for(jane)
  end
end
