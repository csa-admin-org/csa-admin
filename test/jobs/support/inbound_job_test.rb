# frozen_string_literal: true

require "test_helper"

class Support::InboundJobTest < ActiveJob::TestCase
  def ingest(payload)
    perform_enqueued_jobs only: Support::InboundJob do
      Support::InboundJob.perform_later(payload)
    end
  end

  test "appends an allowlisted admin reply" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    payload = {
      "To" => ticket.inbound_email,
      "From" => admins(:external).email,
      "TextBody" => "Pierre follows up",
      "MessageID" => "inbound-1",
      "Headers" => [ { "Name" => "Message-ID", "Value" => "<inbound-1@mail>" } ]
    }

    assert_difference "Support::Message.count", 1 do
      ingest(payload)
    end

    message = ticket.messages.order(:id).last
    assert_equal "Pierre follows up", message.body
    assert_equal "admin", message.author
    assert_equal admins(:external), message.admin
    assert_equal "<inbound-1@mail>", message.rfc_message_id
  end

  test "stores apple mail html and drops cited quote" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    ingest(
      "To" => ticket.inbound_email,
      "From" => admins(:external).email,
      "TextBody" => "Voici le lien\n\nLe lundi, Thibaud a \u00e9crit :\nquoted",
      "HtmlBody" => "<html><body><div>Voici le <a href='https://example.com'>lien</a></div><blockquote type='cite'><div>quoted</div></blockquote></body></html>",
      "MessageID" => "inbound-html",
      "Headers" => [ { "Name" => "Message-ID", "Value" => "<inbound-html@mail>" } ])

    message = ticket.messages.order(:id).last
    assert_includes message.html.to_s, "https://example.com"
    assert_not_includes message.html.to_s, "quoted"
  end

  test "repairs mojibake and cuts a leftover quote dump" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    ingest(
      "To" => ticket.inbound_email,
      "From" => admins(:external).email,
      "TextBody" => "Merci pour la rÃ©solution\n\nLe 06.04.26 Ã  23:26, info@csa-admin.org a Ã©crit :\nquoted",
      "HtmlBody" => "<html><body><p>Merci pour la rÃ©solution</p><p>Le 06.04.26 Ã&nbsp; 23:26, info@csa-admin.org a Ã©critÂ :</p><blockquote>quoted</blockquote></body></html>",
      "MessageID" => "inbound-mojibake",
      "Headers" => [ { "Name" => "Message-ID", "Value" => "<inbound-mojibake@mail>" } ])

    message = ticket.messages.order(:id).last
    assert_includes message.html.to_s, "résolution"
    assert_not_includes message.html.to_s, "quoted"
    assert_not_includes message.html.to_s, "Ã"
  end

  test "drops unknown from addresses" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    assert_no_difference "Support::Message.count" do
      ingest(
        "To" => ticket.inbound_email,
        "From" => "stranger@gmail.com",
        "TextBody" => "Hello",
        "MessageID" => "inbound-2")
    end
  end

  test "is idempotent on message id" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))
    payload = {
      "To" => ticket.inbound_email,
      "From" => admins(:external).email,
      "TextBody" => "Once",
      "Headers" => [ { "Name" => "Message-ID", "Value" => "<same@mail>" } ]
    }

    ingest(payload)
    assert_no_difference "Support::Message.count" do
      ingest(payload)
    end
  end

  test "keeps text and skips oversize attachments" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    ingest(
      "To" => ticket.inbound_email,
      "From" => admins(:external).email,
      "TextBody" => "With a huge file",
      "MessageID" => "inbound-3",
      "Attachments" => [ {
        "Name" => "huge.bin",
        "ContentType" => "application/octet-stream",
        "ContentLength" => HasAttachments::MAXIMUM_SIZE + 1,
        "Content" => Base64.strict_encode64("tiny")
      } ])

    message = ticket.messages.order(:id).last
    assert_equal "With a huge file", message.body
    assert_equal 0, message.attachments.count
  end

  test "turns cid images into action text attachments" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))
    png = Base64.strict_encode64("fake-png")

    ingest(
      "To" => ticket.inbound_email,
      "From" => admins(:external).email,
      "TextBody" => "See screenshot",
      "HtmlBody" => "<div>See <img src='cid:shot@mail' /></div>",
      "MessageID" => "inbound-cid",
      "Headers" => [ { "Name" => "Message-ID", "Value" => "<inbound-cid@mail>" } ],
      "Attachments" => [ {
        "Name" => "shot.png",
        "ContentType" => "image/png",
        "ContentID" => "shot@mail",
        "ContentLength" => 8,
        "Content" => png
      } ])

    message = ticket.messages.order(:id).last
    assert_equal 0, message.attachments.count
    assert message.html.body.attachments.any?
  end

  test "skips empty convert" do
    assert_no_difference "Support::Ticket.count" do
      ingest(
        "To" => "ticket-acme@support.csa-admin.org",
        "From" => ENV["ULTRA_ADMIN_EMAIL"],
        "TextBody" => "",
        "StrippedTextReply" => "",
        "MessageID" => "empty")
    end
  end

  test "drops convert from a non-operator address" do
    assert_no_difference "Support::Ticket.count" do
      ingest(
        "To" => "ticket-acme@support.csa-admin.org",
        "From" => "attacker@gmail.com",
        "TextBody" => "Please help\n\nOn Mon, Jane Doe <#{admins(:external).email}> wrote:\nHello",
        "MessageID" => "convert-attack")
    end
  end

  test "strips the operator signature from an inbound reply" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "ULTRA_ADMIN_NAME" => "Thibaud") do
      ingest(
        "To" => ticket.inbound_email,
        "From" => "info@csa-admin.org",
        "TextBody" => "Voici\n\n++\nThibaud\n\nLe lundi, Jane a écrit :\nquoted",
        "HtmlBody" => "<html><body><p>Voici</p><p>++</p><p>Thibaud</p><blockquote type='cite'><div>quoted</div></blockquote></body></html>",
        "MessageID" => "inbound-sig",
        "Headers" => [ { "Name" => "Message-ID", "Value" => "<inbound-sig@mail>" } ])
    end

    message = ticket.messages.order(:id).last
    assert_equal "support", message.author
    assert_equal "Voici", message.body.strip
    assert_not_includes message.html.to_s, "++"
    assert_not_includes message.html.to_s, "Thibaud"
    assert_not_includes message.html.to_s, "quoted"
  end

  test "converts informal mail from the operator" do
    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org") do
      assert_difference "Support::Ticket.count", 1 do
        ingest(
          "To" => "ticket-acme@support.csa-admin.org",
          "From" => "support+high@csa-admin.org",
          "Subject" => "Re: Informal help",
          "TextBody" => "Here is the answer\n\nOn Mon, Jane Doe <#{admins(:external).email}> wrote:\nHello",
          "Headers" => [ { "Name" => "Message-ID", "Value" => "<convert-1@mail>" } ])
      end
    end

    ticket = Support::Ticket.order(:id).last
    message = ticket.messages.first
    assert_equal "Informal help", ticket.subject
    assert_equal admins(:external), ticket.admin
    assert_equal "support", message.author
    assert_equal "Here is the answer", message.body
    assert message.wrap?
    assert_equal [ admins(:external).email ], ticket.wrap_emails_for(message)
  end

  test "convert is idempotent on message id" do
    payload = {
      "To" => "ticket-acme@support.csa-admin.org",
      "From" => ENV["ULTRA_ADMIN_EMAIL"],
      "TextBody" => "Once",
      "Headers" => [ { "Name" => "Message-ID", "Value" => "<convert-same@mail>" } ]
    }

    ingest(payload)
    assert_no_difference [ "Support::Ticket.count", "Support::Message.count" ] do
      ingest(payload)
    end
  end
end
