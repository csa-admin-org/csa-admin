# frozen_string_literal: true

require "test_helper"

class MailDelivery::PreviewTest < ActiveSupport::TestCase
  test "store_preview_from! redacts session and unsubscribe links but keeps other links" do
    delivery = MailDelivery.create!(
      member: members(:john),
      mailable_type: "Session",
      mailable_ids: [ sessions(:john).id ],
      action: "created",
      state: :processing)
    html = <<~HTML
      <html><body>
        <a href="https://members.acme.test/sessions/tok123?locale=en" class="button button--green" target="_blank" rel="noreferrer noopener">Access my account</a>
        <a href="https://members.acme.test/newsletters/unsubscribe/abc">Unsubscribe</a>
        <a href="https://members.acme.test/memberships">Memberships</a>
      </body></html>
    HTML

    delivery.store_preview_from!(html_message(html))

    login_url = "#{Current.org.members_url}/login"
    assert_includes delivery.content, "Access my account"
    assert_includes delivery.content, "Unsubscribe"
    assert_includes delivery.content, "class=\"button button--green\""
    assert_includes delivery.content, "href=\"#{login_url}\""
    assert_includes delivery.content, "https://members.acme.test/memberships"
    assert_not_includes delivery.content, "/sessions/"
    assert_not_includes delivery.content, "/newsletters/unsubscribe/"
  end

  test "mail_preview redacts already stored sensitive links" do
    delivery = MailDelivery.create!(
      member: members(:john),
      mailable_type: "Newsletter",
      mailable_ids: [ newsletters(:simple).id ],
      action: "newsletter",
      state: :delivered,
      subject: "Subject",
      content: <<~HTML)
        <html><body>
          <a href="https://members.acme.test/newsletters/unsubscribe/abc">Unsubscribe</a>
          <a href="https://members.acme.test/memberships">Memberships</a>
        </body></html>
      HTML

    preview = delivery.mail_preview

    login_url = "#{Current.org.members_url}/login"
    assert_includes preview, "Unsubscribe"
    assert_includes preview, "href=\"#{login_url}\""
    assert_includes preview, "https://members.acme.test/memberships"
    assert_not_includes preview, "/newsletters/unsubscribe/"
    assert_includes preview, 'target="_blank" rel="noopener noreferrer"'
  end

  private

  def html_message(html)
    Mail::Message.new.tap do |message|
      message.content_type = "text/html; charset=UTF-8"
      message.body = html
    end
  end
end
