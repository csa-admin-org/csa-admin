# frozen_string_literal: true

require "test_helper"

class SupportHelperTest < ActionView::TestCase
  test "compacts a bare handbook url in a support reply" do
    message = Support::Message.new(author: "support", body: "voir")
    message.html = "<div>Voir: https://admin.acme.test/handbook/shop#billing</div>"

    I18n.with_locale(:fr) do
      html = view.support_message_html(message)
      link = Nokogiri::HTML.fragment(html).at("a.support-app-link")

      assert link
      assert_equal "Manuel: Épicerie > Facturation", link.text
    end
  end

  test "hides a stored gmail signature on an admin reply" do
    message = Support::Message.new(
      author: "admin",
      body: "Nothing urgent",
      html: <<~HTML)
        <div>Nothing urgent.</div>
        <div>Sam</div>
        <span class="gmail_signature_prefix">-- </span>
        <div class="gmail_signature"><b>Green Farm</b></div>
      HTML

    html = view.support_message_html(message)

    assert_includes html, "Nothing urgent"
    assert_includes html, "Sam"
    assert_not_includes html, "Green Farm"
    assert_not_includes html, "gmail_signature"
  end

  test "hides a stored thunderbird signature image on an admin reply" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "logo.jpeg",
      content_type: "image/jpeg")
    message = Support::Message.new(author: "admin", body: "Thanks")
    message.html = <<~HTML
      <div>Thanks for the update.</div>
      <div class="moz-signature">
        <action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/jpeg" filename="logo.jpeg"></action-text-attachment>
      </div>
    HTML

    html = view.support_message_html(message)

    assert_includes html, "Thanks for the update"
    assert_not_includes html, "moz-signature"
    assert_not_includes html, "logo.jpeg"
    assert_not_includes html, "<img"
  end

  test "shows an infomaniak reaction as the emoji" do
    message = Support::Message.new(author: "admin", body: "reaction")
    message.html = <<~HTML
      <div>
        <table><tr><td><span>👍</span><span> Sam</span> a réagi</td></tr></table>
        <div>Réaction envoyée avec <a href="https://www.infomaniak.com/gtl/apps.kmail">Infomaniak Mail</a></div>
      </div>
    HTML

    html = view.support_message_html(message)

    assert_includes html, "👍"
    assert_not_includes html, "Sam"
    assert_not_includes html, "Infomaniak"
    assert_not_includes html, "<table"
  end

  test "hides a stored infomaniak signature on an admin reply" do
    message = Support::Message.new(
      author: "admin",
      body: "Thanks",
      html: <<~HTML)
        <div>Thanks for the help.</div>
        <div>Sam</div>
        <div data-ik-opengraph-ignore="">
          <p><b>Green Farm</b></p>
          <div><img src="https://workspace.storage.infomaniak.com/signature/logo" alt="sign"></div>
        </div>
      HTML

    html = view.support_message_html(message)

    assert_includes html, "Thanks for the help"
    assert_includes html, "Sam"
    assert_not_includes html, "Green Farm"
    assert_not_includes html, "infomaniak"
  end

  test "hides a proton quote stored on an admin reply" do
    message = Support::Message.new(
      author: "admin",
      body: "Yes super",
      html: <<~HTML)
        <div>Yes super ! Merci :)</div>
        <div class="protonmail_quote">-------- Original Message --------<br>quoted</div>
      HTML

    html = view.support_message_html(message)

    assert_includes html, "Yes super"
    assert_not_includes html, "Original Message"
    assert_not_includes html, "quoted"
  end

  test "hides a proton sent-from line stored inside action text" do
    message = Support::Message.new(author: "admin", body: "Oui")
    message.html = <<~HTML
      <p>Oui bien sûr !</p>
      <pre><code>    Arthur Pasquier
</code></pre>
    HTML

    html = view.support_message_html(message)

    assert_includes html, "Oui bien sûr"
    assert_not_includes html, "Pasquier"
    assert_not_includes html, "<pre"
  end

  test "drops a stored client font size on an admin reply" do
    message = Support::Message.new(author: "admin", body: "merci")
    message.html = %(<div style="font-family: Arial, sans-serif; font-size: 14px;">top - merci beaucoup ! manuel</div>)

    html = view.support_message_html(message)

    assert_includes html, "merci beaucoup"
    assert_not_includes html, "font-size"
    assert_not_includes html, "font-family"
    assert_not_includes html, "style="
  end

  test "keeps a resolved highlight and drops a tracking image style" do
    message = Support::Message.new(author: "admin", body: "painted")
    message.html = <<~HTML
      <p><span style="color: rgb(207, 0, 0); font-size: 14px;">painted</span></p>
      <img style="background-image: url(https://evil.example/pixel)" src="https://example.com/a.png" alt="shot">
    HTML

    html = view.support_message_html(message)

    assert_includes html, "color: rgb(207, 0, 0)"
    assert_includes html, "painted"
    assert_not_includes html, "font-size"
    assert_not_includes html, "evil.example"
    assert_not_includes html, "background-image"
  end

  test "renders stored action text images" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "shot.png",
      content_type: "image/png")
    message = Support::Message.new(author: "support", body: "See screenshot")
    message.html = %(<div>See <action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/png" filename="shot.png"></action-text-attachment></div>)

    html = view.support_message_html(message)

    assert_includes html, "See"
    assert_includes html, "shot.png"
    assert_match %r{<img[^>]+src="[^"]*/rails/active_storage/}, html
    assert_not_includes html, "action-text-attachment"
    assert_not_includes html, "trix-content"
  end

  test "keeps a cited original on a converted support message" do
    message = Support::Message.new(
      author: "support",
      body: "Here is the answer",
      html: <<~HTML)
        <p>Here is the answer</p>
        <blockquote type="cite"><div>Hello from the member</div></blockquote>
      HTML

    html = view.support_message_html(message)

    assert_includes html, "Hello from the member"
  end

  test "collapses stored mail breaks on a support message" do
    message = Support::Message.new(
      author: "support",
      body: "Answer",
      html: <<~HTML)
        <div>Answer.</div>
        <div><br></div>
        <div><br></div>
        <blockquote type="cite"><div>Quoted question?</div></blockquote>
        <div><br></div>
        <div>Next.</div>
      HTML

    html = view.support_message_html(message)
    spacers = Nokogiri::HTML.fragment(html).css("div").select { |node| node.inner_html == "<br>" }

    assert_includes html, "Quoted question"
    assert_empty spacers
  end

  test "shows a pre-fix convert file on the opening message" do
    ticket = convert_ticket
    now = Time.current
    opening = quiet_message(ticket, author: "admin", admin: admins(:external), body: "Le panier manque.")
    reply = quiet_message(
      ticket,
      author: "support",
      body: "Voici la réponse.",
      html: '<div>Voici la photo.</div><div><img src="https://example.test/shot.png" alt="shot.png"></div>')
    attach_support_file(reply, "invoice.pdf", "notes.pdf", "application/pdf")
    attach_support_file(reply, "logo.png", "shot.png", "image/png")
    later = quiet_message(ticket, author: "support", body: "Plus tard.")
    attach_support_file(later, "invoice.pdf", "later.pdf", "application/pdf")
    opening.update_columns(created_at: now, rfc_message_id: nil)
    reply.update_columns(created_at: now + 0.2.seconds)
    later.update_columns(created_at: now + 1.hour)

    opening_images, opening_files = support_message_attachments(opening)
    reply_images, reply_files = support_message_attachments(reply)
    reply_html = view.support_message_html(reply)
    opening_html = view.support_message_html(opening)

    assert_equal [ "notes.pdf" ], filenames_of(opening_files)
    assert_empty opening_images
    assert_empty reply_files
    assert_equal [ "shot.png" ], filenames_of(reply_images)
    assert_equal [ "later.pdf" ], filenames_of(support_message_attachments(later).last)
    assert_includes reply_html, "shot.png"
    assert_not_includes opening_html, "shot.png"
  end

  test "keeps a later support file and a normal inbound file where they were stored" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Panier", content: "Ouverture", admin: admins(:external))
    opening = ticket.messages.first
    later = quiet_message(ticket, author: "support", body: "Réponse plus tard.")
    inbound = quiet_message(ticket, author: "admin", admin: admins(:external), body: "Encore une pièce.")
    attach_support_file(later, "invoice.pdf", "later.pdf", "application/pdf")
    attach_support_file(inbound, "invoice.pdf", "inbound.pdf", "application/pdf")
    later.update_columns(created_at: opening.created_at + 1.hour)
    inbound.update_columns(created_at: opening.created_at + 2.hours)

    assert_empty support_message_attachments(opening).last
    assert_equal [ "later.pdf" ], filenames_of(support_message_attachments(later).last)
    assert_equal [ "inbound.pdf" ], filenames_of(support_message_attachments(inbound).last)
  end

  test "ticket_admins_collection only drops the ticket admin filter" do
    relation = Support::Ticket.joins(:messages).where(
      admin_id: admins(:ultra).id,
      support_messages: { admin_id: admins(:ultra).id })

    assert_not_deprecated(ActiveRecord.deprecator) do
      ticket_admins_collection(relation).load
    end
  end

  def convert_ticket
    ticket = Support::Ticket.new(
      priority: :normal,
      subject: "Panier",
      content: "Ouverture",
      admin: admins(:external),
      skip_opening_message: true)
    ticket.save!
    ticket
  end

  def quiet_message(ticket, **attrs)
    message = ticket.messages.build(**attrs)
    message.skip_notify = true
    message.save!
    message
  end

  def attach_support_file(message, fixture, filename, content_type)
    message.attachments.build.file.attach(
      io: StringIO.new(file_fixture(fixture).binread),
      filename: filename,
      content_type: content_type)
    message.save!
    message
  end

  def filenames_of(attachments)
    attachments.map { |attachment| attachment.file.filename.to_s }
  end
end
