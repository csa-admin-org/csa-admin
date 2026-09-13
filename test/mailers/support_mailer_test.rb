# frozen_string_literal: true

require "test_helper"

class SupportMailerTest < ActionMailer::TestCase
  setup do
    @ticket = Support::Ticket.create!(
      priority: :high,
      subject: "Test Subject",
      content: "Test content",
      context: "Member 42",
      admin: admins(:external))
    @message = @ticket.messages.first
  end

  test "ping_email from high@ for high tickets" do
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      mail = SupportMailer.with(message: @message).ping_email

      assert_equal [ "support@csa-admin.org" ], mail.to
      assert_equal [ "high@support.csa-admin.org" ], mail.from
      assert_equal "CSA Admin 🛟‼️", mail[:from].display_names.first
      assert_equal "🛟‼️ Test Subject", mail.subject
      assert_equal [ @ticket.inbound_email ], mail.reply_to
      assert_includes mail.body.encoded, "Test content"
      assert_includes mail.body.encoded, "Member 42"
    end
  end

  test "ping_email from medium@ for medium tickets" do
    @ticket.update!(priority: :medium)
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      mail = SupportMailer.with(message: @message).ping_email

      assert_equal [ "support@csa-admin.org" ], mail.to
      assert_equal [ "medium@support.csa-admin.org" ], mail.from
      assert_equal "CSA Admin 🛟❗️", mail[:from].display_names.first
    end
  end

  test "ping_email from normal@ for normal tickets" do
    @ticket.update!(priority: :normal)
    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      mail = SupportMailer.with(message: @message).ping_email

      assert_equal [ "support@csa-admin.org" ], mail.to
      assert_equal [ "normal@support.csa-admin.org" ], mail.from
      assert_equal "CSA Admin 🛟", mail[:from].display_names.first
    end
  end

  test "wrap_email to participants minus author" do
    reply = @ticket.messages.create!(
      author: "support",
      body: "Here is the answer",
      via: :app)

    mail = SupportMailer.with(message: reply).wrap_email

    assert_equal [ admins(:external).email ], mail.to
    assert_match(/\ARe: /, mail.subject)
    assert_includes mail.body.encoded, "Here is the answer"
    assert_includes mail.body.encoded, @ticket.show_url
    assert_includes mail.body.encoded, "CSA-ADMIN-REPLY-ABOVE"
    assert_includes mail.body.encoded, "csa-admin-reply-above"
    assert_not_includes mail.body.encoded, "CSA Admin support replied"
  end

  test "wrap_email signs support replies" do
    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      reply = @ticket.messages.create!(
        author: "support",
        body: "Here is the answer",
        via: :app)

      mail = SupportMailer.with(message: reply).wrap_email
      text = mail.text_part.body.to_s
      html = mail.html_part.body.to_s

      assert_includes text, "Here is the answer"
      assert_includes text, "++\nThibaud"
      assert_includes html, "<p>++<br>Thibaud</p>"
    end
  end

  test "wrap_email signs stored html" do
    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      reply = @ticket.messages.create!(
        author: "support",
        body: "Here is the answer",
        via: :app)
      reply.update!(html: "<p>Here is the answer</p>")

      mail = SupportMailer.with(message: reply.reload).wrap_email
      html = mail.html_part.body.to_s

      assert_includes html, "<p>Here is the answer</p>"
      assert_includes html, "<p>++<br>Thibaud</p>"
    end
  end

  test "wrap_email does not double-sign" do
    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      reply = @ticket.messages.create!(
        author: "support",
        body: "Here is the answer\n\n++\nThibaud",
        via: :app)

      mail = SupportMailer.with(message: reply).wrap_email

      assert_equal 1, mail.text_part.body.to_s.scan(/\+\+\nThibaud/).size
    end
  end

  test "wrap_email does not sign admin hops" do
    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      follow_up = @ticket.messages.create!(
        author: "admin",
        admin: admins(:super),
        body: "Jane follows up",
        via: :app)

      mail = SupportMailer.with(message: follow_up).wrap_email

      assert_includes mail.text_part.body.to_s, "Jane follows up"
      assert_not_includes mail.text_part.body.to_s, "++\nThibaud"
    end
  end

  test "ping_email does not sign" do
    with_env(
      "SUPPORT_EMAIL" => "support@csa-admin.org",
      "ULTRA_ADMIN_NAME" => "Thibaud") do
      reply = @ticket.messages.create!(
        author: "support",
        body: "Here is the answer",
        via: :app)
      mail = SupportMailer.with(message: reply).ping_email

      assert_includes mail.body.encoded, "Here is the answer"
      assert_not_includes mail.body.encoded, "++"
    end
  end

  test "wrap_email quotes the previous message under the new body" do
    reply = @ticket.messages.create!(
      author: "support",
      body: "Here is the answer",
      via: :app)

    mail = SupportMailer.with(message: reply).wrap_email
    text = mail.text_part.body.to_s
    html = mail.html_part.body.to_s

    assert_includes text, "Here is the answer"
    assert_includes text, "External Consultant"
    assert_includes text, "> Test content"
    assert_operator text.index("CSA-ADMIN-REPLY-ABOVE"), :<, text.index("Here is the answer")
    assert_operator text.index("Here is the answer"), :<, text.index("> Test content")
    assert_not_includes text, "Member 42"

    assert_includes html, "id=\"csa-admin-reply-above\""
    assert_includes html, "Here is the answer"
    assert_includes html, "External Consultant"
    assert_includes html, "Test content"
    assert_includes html, "blockquote"
    assert_operator html.index("id=\"csa-admin-reply-above\""), :<, html.index("Here is the answer")
    assert_operator html.index("Here is the answer"), :<, html.index("Test content")
  end

  test "wrap_email quotes a previous support hop without the wrap signature" do
    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      @ticket.messages.create!(
        author: "support",
        body: "Here is the answer",
        via: :app)
      follow_up = @ticket.messages.create!(
        author: "admin",
        admin: admins(:super),
        body: "Jane follows up",
        via: :app)

      mail = SupportMailer.with(message: follow_up).wrap_email
      text = mail.text_part.body.to_s
      quoted = text.split("Jane follows up", 2).last

      assert_includes quoted, "> Here is the answer"
      assert_not_includes quoted, "++"
    end
  end

  test "ping_email includes context on later hops" do
    follow_up = @ticket.messages.create!(
      author: "admin",
      admin: admins(:super),
      body: "Jane follows up",
      via: :app)

    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      mail = SupportMailer.with(message: follow_up).ping_email

      assert_includes mail.body.encoded, "Jane follows up"
      assert_includes mail.body.encoded, "Member 42"
    end
  end

  test "wrap_email is a no-op without participants" do
    @ticket.update!(admin: nil)
    @ticket.messages.where(author: "admin").update_all(admin_id: nil)
    reply = @ticket.messages.create!(author: "support", body: "Answer", via: :app)

    mail = SupportMailer.with(message: reply).wrap_email
    assert_nil mail.to
  end
end
