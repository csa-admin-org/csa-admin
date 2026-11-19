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

  test "wrap_email keeps a table in the html part" do
    reply = @ticket.messages.create!(
      author: "support",
      html: "<p>Combinations:</p><table><tbody><tr><th>Wednesday</th></tr><tr><td>Wintershare Wednesday</td></tr></tbody></table>")

    html = SupportMailer.with(message: reply.reload).wrap_email.html_part.body.to_s

    assert_includes html, "<table>"
    assert_includes html, "<th>Wednesday</th>"
    assert_includes html, "<td>Wintershare Wednesday</td>"
    assert_not_includes html, "WednesdayWintershare"
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
    assert_includes html, "quoted_header"
    assert_includes html, "External Consultant"
    assert_includes html, "Test content"
    assert_includes html, "blockquote"
    assert_operator html.index("id=\"csa-admin-reply-above\""), :<, html.index("Here is the answer")
    assert_operator html.index("Here is the answer"), :<, html.index("quoted_header")
    assert_operator html.index("quoted_header"), :<, html.index("<blockquote")
    assert_operator html.index("<blockquote"), :<, html.index("Test content")
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

  test "converted wrap email nudges the admin toward the in-app form" do
    {
      "en" => "support request form",
      "fr" => "formulaire de demande de support",
      "de" => "Formular für Supportanfragen",
      "it" => "modulo di richiesta di supporto",
      "nl" => "formulier voor ondersteuningsverzoeken"
    }.each do |language, phrase|
      mail = converted_wrap_mail(language)
      text = mail.text_part.body.to_s
      html = mail.html_part.body.to_s
      url = admin_support_tickets_url
      link = Nokogiri::HTML(html).at_css("p.form_nudge a")

      assert_equal [ admins(:external).email ], mail.to
      assert_includes text, I18n.t("support.mailer.form_nudge_text", locale: language, url: url)
      assert_equal url, link["href"]
      assert_equal phrase, link.text
      assert_operator text.index("++\nThibaud"), :<, text.index(phrase)
      assert_operator text.index(phrase), :<, text.index("> Hello")
      assert_operator html.index("Thibaud"), :<, html.index("form_nudge")
      assert_operator html.index("form_nudge"), :<, html.index("quoted_header")
      mail.deliver_now
      nudge = Nokogiri::HTML(ActionMailer::Base.deliveries.last.html_part.body.to_s)
        .at_css("p.form_nudge")
      assert_includes nudge["style"], "font-size: 13px"
      assert_includes nudge["style"], "color: #6b7280"
    end
  end

  test "wrap email omits the form nudge except on a converted reply" do
    admins(:external).update!(language: "en")
    phrase = "support request form"
    url = admin_support_tickets_url

    reply = @ticket.messages.create!(
      author: "support",
      body: "Here is the answer",
      via: :app)
    ordinary = wrap_mail_for(reply)
    assert_not ordinary[:params][:form_nudge]
    assert_form_nudge_absent(ordinary[:mail], phrase, url)

    converted_wrap_mail("en")
    ticket = Support::Ticket.order(:id).last
    follow_up = wrap_mail_for(ticket.messages.create!(
      author: "support",
      body: "A later reply",
      via: :app))
    assert_not follow_up[:params][:form_nudge]
    assert_form_nudge_absent(follow_up[:mail], phrase, url)

    with_env("SUPPORT_EMAIL" => "support@csa-admin.org") do
      ping = SupportMailer.with(message: reply, form_nudge: true).ping_email
      assert_not_includes ping.body.encoded, phrase
      assert_not_includes ping.body.encoded, "(#{url})"
    end
  end

  private

  def converted_wrap_mail(language)
    admins(:external).update!(language: language)
    params = nil
    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "ULTRA_ADMIN_NAME" => "Thibaud",
      "SUPPORT_EMAIL" => "support@csa-admin.org") do
      params = wrap_params_during do
        Support::Ticket.convert_inbound(Support::Inbound.parse(
          "To" => "ticket-acme@support.csa-admin.org",
          "From" => "support+high@csa-admin.org",
          "Subject" => "Re: Informal help #{language}",
          "TextBody" => <<~TEXT,
            Here is the answer

            On Mon, Jane Doe <#{admins(:external).email}> wrote:
            Hello
          TEXT
          "Headers" => [ {
            "Name" => "Message-ID",
            "Value" => "<convert-nudge-#{language}@mail>"
          } ]))
      end
    end
    assert params[:form_nudge]
    SupportMailer.with(params).wrap_email
  end

  def wrap_mail_for(message)
    params = wrap_params.find { |payload| payload[:message] == message }
    assert params, "expected a wrap_email for message #{message.id}"
    { params: params, mail: SupportMailer.with(params).wrap_email }
  end

  def wrap_params_during
    before = enqueued_jobs.map { |job| job["job_id"] }
    yield
    payloads = enqueued_jobs.filter_map { |job|
      wrap_job_params(job) unless before.include?(job["job_id"])
    }
    assert_equal 1, payloads.size
    payloads.first
  end

  def wrap_params
    enqueued_jobs.filter_map { |job| wrap_job_params(job) }
  end

  def wrap_job?(job)
    job[:job] == ActionMailer::MailDeliveryJob && job[:args][1] == "wrap_email"
  end

  def wrap_job_params(job)
    return unless wrap_job?(job)

    raw = job[:args].find { |arg|
      arg.is_a?(Hash) && (arg["params"] || arg[:params])
    }
    ActiveJob::Arguments.deserialize([ raw ]).first[:params]
  end

  def assert_form_nudge_absent(mail, phrase, url)
    text = mail.text_part.body.to_s
    html = mail.html_part.body.to_s
    assert_not_includes text, phrase
    assert_not_includes html, phrase
    assert_nil Nokogiri::HTML(html).at_css("p.form_nudge")
    assert_not_includes text, "(#{url})"
  end

  def admin_support_tickets_url
    Rails.application.routes.url_helpers.support_tickets_url(
      **Tenant.local_url_options(Tenant.admin_host))
  end
end
