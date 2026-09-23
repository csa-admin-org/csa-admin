# frozen_string_literal: true

require "test_helper"

class SupportHelperTest < ActionView::TestCase
  include SupportHelper

  test "compacts a bare handbook url in a support reply" do
    message = Support::Message.new(author: "support", body: "voir")
    message.html = "<div>Voir: https://admin.acme.test/handbook/shop#billing</div>"

    I18n.with_locale(:fr) do
      html = support_message_html(message)
      link = Nokogiri::HTML.fragment(html).at("a.support-app-link")

      assert link
      assert_equal "Manuel: Épicerie > Facturation", link.text
    end
  end

  test "hides a proton quote stored on an admin reply" do
    message = Support::Message.new(
      author: "admin",
      body: "Yes super",
      html: <<~HTML)
        <div>Yes super ! Merci :)</div>
        <div class="protonmail_quote">-------- Original Message --------<br>quoted</div>
      HTML

    html = support_message_html(message)

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

    html = support_message_html(message)

    assert_includes html, "Oui bien sûr"
    assert_not_includes html, "Pasquier"
    assert_not_includes html, "<pre"
  end

  test "keeps a cited original on a converted support message" do
    message = Support::Message.new(
      author: "support",
      body: "Here is the answer",
      html: <<~HTML)
        <p>Here is the answer</p>
        <blockquote type="cite"><div>Hello from the member</div></blockquote>
      HTML

    html = support_message_html(message)

    assert_includes html, "Hello from the member"
  end
end
