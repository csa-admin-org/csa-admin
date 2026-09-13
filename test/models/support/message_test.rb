# frozen_string_literal: true

require "test_helper"

class Support::MessageTest < ActiveSupport::TestCase
  def create_ticket
    Support::Ticket.create!(
      priority: :normal, subject: "Test", content: "Opening", admin: admins(:external))
  end

  test "requires a body" do
    ticket = create_ticket
    message = ticket.messages.build(author: "admin", admin: admins(:external), body: "")

    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test "opening admin message pings and does not wrap" do
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      ticket = create_ticket
      message = ticket.messages.first

      assert message.opening?
      assert_not message.wrap?
      assert message.ping?
    end
  end

  test "admin follow-up wraps other participants and pings" do
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      ticket = create_ticket
      message = ticket.messages.create!(
        author: "admin", admin: admins(:super), body: "Jane follows up", via: :app)

      assert message.wrap?
      assert message.ping?
      assert_equal [ admins(:external).email ], ticket.wrap_emails_for(message)
    end
  end

  test "support inbound does not ping" do
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      ticket = create_ticket
      message = ticket.messages.create!(
        author: "support", body: "Thibaud from Mail.app", via: :inbound)

      assert message.wrap?
      assert_not message.ping?
    end
  end

  test "support app reply does not ping" do
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      ticket = create_ticket
      message = ticket.messages.create!(
        author: "support", body: "Avec plaisir", via: :app)

      assert message.wrap?
      assert_not message.ping?
    end
  end

  test "admin inbound wraps other participants and pings" do
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      ticket = create_ticket
      ticket.messages.create!(author: "admin", admin: admins(:super), body: "Jane follows up", via: :app)
      message = ticket.messages.create!(
        author: "admin", admin: admins(:external), body: "Pierre replies", via: :inbound)

      assert message.wrap?
      assert message.ping?
      assert_equal [ admins(:super).email ], ticket.wrap_emails_for(message)
    end
  end

  test "does not mail or webhook in demo" do
    ticket = create_ticket
    Support::Ticket.stub(:webhook_url, "https://webhook.example/support") do
      with_demo_tenant do
        assert_no_enqueued_jobs do
          ticket.messages.create!(author: "admin", admin: admins(:external), body: "Demo")
        end
      end
    end
  end

  test "snapshots admin_name and keeps it after the admin is deleted" do
    ticket = create_ticket
    message = ticket.messages.first
    name = admins(:external).name

    assert_equal name, message.admin_name
    assert_equal name, message.display_name
    assert_not message.unknown_author?

    admins(:external).destroy!

    message.reload
    assert_nil message.admin_id
    assert_equal name, message.admin_name
    assert_equal name, message.display_name
    assert_not message.unknown_author?
  end

  test "unknown author when no admin was matched" do
    ticket = create_ticket
    message = ticket.messages.build(author: "admin", body: "Unmatched inbound", via: :inbound)
    message.skip_notify = true
    message.save!

    assert message.unknown_author?
    assert_equal I18n.t("active_admin.unknown"), message.display_name
  end

  test "skip_notify does not ping or wrap" do
    ticket = create_ticket
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        message = ticket.messages.build(author: "support", body: "Imported answer", via: :import)
        message.skip_notify = true
        message.save!
      end
    end
  end
end
