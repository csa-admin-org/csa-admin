# frozen_string_literal: true

require "test_helper"

class Support::InboundJobTest < ActiveJob::TestCase
  def ingest(payload)
    Support::InboundJob.new.perform(payload)
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

  test "keeps inline apple mail quotes and drops the trailing thread" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))
    html = <<~HTML
      <html><body>
        <div>Salut,</div>
        <div><blockquote type="cite"><div>Question about the invoice?</div></blockquote></div>
        <div>The invoice was rebuilt.</div>
        <blockquote type="cite"><div>Could we force the annual number?</div></blockquote>
        <div>A checkbox would do that.</div>
        <div><blockquote type="cite"><div>On 9 Oct 2026, at 08:17, CSA Admin wrote:</div><div>Old thread</div></blockquote></div>
      </body></html>
    HTML

    ingest(
      "To" => ticket.inbound_email,
      "From" => admins(:external).email,
      "TextBody" => "Salut\n\n> Question about the invoice?\n\nThe invoice was rebuilt.",
      "HtmlBody" => html,
      "MessageID" => "inbound-inline-quote",
      "Headers" => [ { "Name" => "Message-ID", "Value" => "<inbound-inline-quote@mail>" } ])

    message = ticket.messages.order(:id).last
    assert_includes message.html.to_s, "Question about the invoice"
    assert_includes message.html.to_s, "Could we force"
    assert_includes message.body, "Question about the invoice"
    assert_not_includes message.html.to_s, "Old thread"
    assert_not_includes message.body, "Old thread"
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

  test "raises for unknown from addresses" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    assert_no_difference "Support::Message.count" do
      assert_raises Support::Inbound::UnknownSender do
        ingest(
          "To" => ticket.inbound_email,
          "From" => "stranger@gmail.com",
          "TextBody" => "Hello",
          "MessageID" => "inbound-2")
      end
    end
  end

  test "appends a reply from an extra operator address" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org",
      "SUPPORT_EXTRA_EMAILS" => "thibaud@thibaud.gg") do
      assert_difference "Support::Message.count", 1 do
        ingest(
          "To" => ticket.inbound_email,
          "From" => "thibaud@thibaud.gg",
          "TextBody" => "Operator follows up",
          "MessageID" => "inbound-extra",
          "Headers" => [ { "Name" => "Message-ID", "Value" => "<inbound-extra@mail>" } ])
      end
    end

    message = ticket.messages.order(:id).last
    assert_equal "support", message.author
    assert_nil message.admin
    assert_equal "Operator follows up", message.body
  end

  test "raises for unknown from addresses when extra operators are configured" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org",
      "SUPPORT_EXTRA_EMAILS" => "thibaud@thibaud.gg") do
      assert_no_difference "Support::Message.count" do
        assert_raises Support::Inbound::UnknownSender do
          ingest(
            "To" => ticket.inbound_email,
            "From" => "stranger@gmail.com",
            "TextBody" => "Hello",
            "MessageID" => "inbound-extra-unknown")
        end
      end
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

  test "raises for an unrecognized recipient" do
    assert_no_difference [ "Support::Ticket.count", "Support::Message.count" ] do
      error = assert_raises Support::Inbound::UnrecognizedAddress do
        ingest(
          "To" => "noreply@example.com",
          "From" => admins(:external).email,
          "TextBody" => "Hello",
          "MessageID" => "inbound-unrecognized")
      end
      assert_includes error.message, "example.com"
    end
  end

  test "raises for convert from a non-operator address" do
    assert_no_difference "Support::Ticket.count" do
      assert_raises Support::Inbound::RejectedSender do
        ingest(
          "To" => "ticket-acme@support.csa-admin.org",
          "From" => "attacker@gmail.com",
          "TextBody" => "Please help\n\nOn Mon, Jane Doe <#{admins(:external).email}> wrote:\nHello",
          "MessageID" => "convert-attack")
      end
    end
  end

  test "converts informal mail from an extra operator address" do
    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org",
      "SUPPORT_EXTRA_EMAILS" => "thibaud@thibaud.gg") do
      assert_difference "Support::Ticket.count" => 1, "Support::Message.count" => 2 do
        ingest(
          "To" => "ticket-acme@support.csa-admin.org",
          "From" => "thibaud@thibaud.gg",
          "Subject" => "Re: Informal help",
          "TextBody" => "Here is the answer\n\nOn Mon, Jane Doe <#{admins(:external).email}> wrote:\nHello",
          "Headers" => [ { "Name" => "Message-ID", "Value" => "<convert-extra@mail>" } ])
      end
    end

    ticket = Support::Ticket.order(:id).last
    original, reply = ticket.messages.order(:id).to_a
    assert_equal "Informal help", ticket.subject
    assert_equal admins(:external), ticket.admin
    assert_equal "admin", original.author
    assert_equal "Hello", original.body.strip
    assert_equal "support", reply.author
    assert_equal "Here is the answer", reply.body.strip
  end

  test "raises for convert from a non-operator address when extra operators are configured" do
    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org",
      "SUPPORT_EXTRA_EMAILS" => "thibaud@thibaud.gg") do
      assert_no_difference "Support::Ticket.count" do
        assert_raises Support::Inbound::RejectedSender do
          ingest(
            "To" => "ticket-acme@support.csa-admin.org",
            "From" => "attacker@gmail.com",
            "TextBody" => "Please help\n\nOn Mon, Jane Doe <#{admins(:external).email}> wrote:\nHello",
            "MessageID" => "convert-extra-attack")
        end
      end
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
      assert_difference "Support::Ticket.count" => 1, "Support::Message.count" => 2 do
        ingest(
          "To" => "ticket-acme@support.csa-admin.org",
          "From" => "support+high@csa-admin.org",
          "Subject" => "Re: Informal help",
          "TextBody" => "Here is the answer\n\nOn Mon, Jane Doe <#{admins(:external).email}> wrote:\nHello",
          "Headers" => [ { "Name" => "Message-ID", "Value" => "<convert-1@mail>" } ])
      end
    end

    ticket = Support::Ticket.order(:id).last
    original, reply = ticket.messages.order(:id).to_a
    assert_equal "Informal help", ticket.subject
    assert_equal admins(:external), ticket.admin
    assert_equal "admin", original.author
    assert_equal admins(:external), original.admin
    assert_equal "Hello", original.body.strip
    assert_not_includes original.body, "On Mon"
    assert_equal "support", reply.author
    assert_equal "Here is the answer", reply.body.strip
    assert_not_includes reply.body, "Hello"
    assert reply.wrap?
    assert_not original.wrap?
    assert_equal [ admins(:external).email ], ticket.wrap_emails_for(reply)
  end

  test "converts an apple mail curly-quoted original to the matching admin" do
    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org") do
      ingest(
        "To" => "ticket-acme@support.csa-admin.org",
        "From" => "support+high@csa-admin.org",
        "Subject" => "Re: Informal help",
        "TextBody" => "Here is the answer\n\n\u201cOn 4 Oct 2026, at 23:52, Jane Doe <#{admins(:external).email}> wrote:\nHello",
        "Headers" => [ { "Name" => "Message-ID", "Value" => "<convert-curly@mail>" } ])
    end

    ticket = Support::Ticket.order(:id).last
    original, reply = ticket.messages.order(:id).to_a
    assert_equal admins(:external), ticket.admin
    assert_equal "admin", original.author
    assert_equal "Hello", original.body.strip
    assert_not_includes original.body, "On 4 Oct"
    assert_equal "Here is the answer", reply.body.strip
    assert reply.wrap?
  end

  test "converts a cited html original into a separate opening message" do
    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org") do
      ingest(
        "To" => "ticket-acme@support.csa-admin.org",
        "From" => "support+high@csa-admin.org",
        "Subject" => "Re: Informal help",
        "TextBody" => "Here is the answer\n\nOn Mon, Jane Doe <#{admins(:external).email}> wrote:\nHello from the member",
        "HtmlBody" => "<html><body><p>Here is the answer</p><blockquote type='cite'><p>On Mon, Jane Doe wrote:</p><p>Hello from the member</p></blockquote></body></html>",
        "Headers" => [ { "Name" => "Message-ID", "Value" => "<convert-html@mail>" } ])
    end

    ticket = Support::Ticket.order(:id).last
    original, reply = ticket.messages.order(:id).to_a
    assert_equal "admin", original.author
    assert_includes original.html.to_s, "Hello from the member"
    assert_not_includes original.html.to_s, "On Mon"
    assert_not_includes original.html.to_s, "Here is the answer"
    assert_includes reply.html.to_s, "Here is the answer"
    assert_not_includes reply.html.to_s, "Hello from the member"
  end

  test "converts an html-only apple mail cite to the matching admin" do
    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org") do
      ingest(
        "To" => "ticket-acme@support.csa-admin.org",
        "From" => "support+high@csa-admin.org",
        "Subject" => "Re: Informal help",
        "TextBody" => "",
        "HtmlBody" => "<html><body><p>Here is the answer</p><blockquote type=\"cite\">On 1 Jan 2000, at 12:00, Jane Doe &lt;#{admins(:external).email}&gt; wrote:<br>Hello</blockquote></body></html>",
        "Headers" => [ { "Name" => "Message-ID", "Value" => "<convert-html-only-admin@mail>" } ])
    end

    ticket = Support::Ticket.order(:id).last
    original = ticket.messages.order(:id).first
    assert_equal admins(:external), ticket.admin
    assert_equal admins(:external), original.admin
  end

  test "converts an apple mail html-only cite with a header blockquote and inline image" do
    png = Base64.strict_encode64("fake-png")
    html = <<~HTML
      <html><body>
        <div dir="ltr">
          <div>Here is the answer</div>
          <div>++</div>
          <div>Thibaud</div>
        </div>
        <div dir="ltr">
          <blockquote type="cite">On 13 Oct 2026, at 06:19, Jane Doe &lt;#{admins(:external).email}&gt; wrote:<br><br></blockquote>
        </div>
        <blockquote type="cite">
          <div dir="ltr">
            <div>Hello from the member</div>
            <div><img alt="image.png" src="cid:shot@mail"></div>
            <div>---</div>
            <div>Jane Doe</div>
            <div>Org desk</div>
          </div>
        </blockquote>
      </body></html>
    HTML

    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org") do
      assert_difference "Support::Ticket.count" => 1, "Support::Message.count" => 2 do
        ingest(
          "To" => "ticket-acme@support.csa-admin.org",
          "From" => "support+high@csa-admin.org",
          "Subject" => "Re: Informal help",
          "TextBody" => "",
          "StrippedTextReply" => "",
          "HtmlBody" => html,
          "MessageID" => "convert-html-only",
          "Headers" => [ { "Name" => "Message-ID", "Value" => "<convert-html-only@mail>" } ],
          "Attachments" => [ {
            "Name" => "image.png",
            "ContentType" => "image/png",
            "ContentID" => "shot@mail",
            "ContentLength" => 8,
            "Content" => png
          } ])
      end
    end

    ticket = Support::Ticket.order(:id).last
    original, reply = ticket.messages.order(:id).to_a
    assert original.body.present?
    assert reply.body.present?
    assert_includes original.body, "Hello from the member"
    assert_not_includes original.body, "Here is the answer"
    assert_not_includes original.body, "On 13 Oct"
    assert_includes original.html.to_s, "Hello from the member"
    assert_includes reply.body, "Here is the answer"
    assert_not_includes reply.body, "Hello from the member"
    assert_not_includes reply.html.to_s, "On 13 Oct"
  end

  test "does not discard inbound policy errors" do
    discarded = Support::InboundJob.rescue_handlers.filter_map { |klass, _|
      name = klass.to_s
      name if name.start_with?("Support::Inbound")
    }

    assert_empty discarded
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
