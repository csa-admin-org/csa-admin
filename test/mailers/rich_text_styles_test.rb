# frozen_string_literal: true

require "test_helper"

class RichTextStylesTest < ActionMailer::TestCase
  test "mailer dark rules color a trix div and a saved paragraph" do
    css = Rails.root.join("app/assets/stylesheets/mailer.css").read
    media = css[/@media \(prefers-color-scheme: dark\) \{([\s\S]*?)\n\}/, 1]
    forced = css[/body\.dark p,[\s\S]*?color: #eee !important;\n\}/]

    [ media, forced ].each do |block|
      assert_includes block, ".trix-content div"
      assert_includes block, ".trix-content pre"
      assert_includes block, ".trix-content figure"
      assert_includes block, "p,"
    end

    html = render_mail(<<~HTML)
      <div class="trix-content"><div>Legacy note</div></div>
      <div class="trix-content"><p>Saved note</p></div>
    HTML

    assert_includes html, "Legacy note"
    assert_includes html, "Saved note"
    assert_match(/mailer.*\.css/, html)
  end

  test "mailer headings style stored h2 and h3 without growing legacy h1" do
    css = Rails.root.join("app/assets/stylesheets/mailer.css").read
    size = css[/h2,\n\.trix-content h1,[\s\S]*?\}/]

    assert_includes size, ".trix-content h2,"
    assert_includes size, ".trix-content h3"
    assert_includes size, ".trix-content h4"
    assert_includes size, "font-size: 20px;"
    assert_includes css, ".trix-content h1,\n.trix-content h2,\n.trix-content h3,\n.trix-content h4 {\n  margin: 0 0 1em;\n}"
  end

  test "mailer styles a saved paragraph and a table past the universal reset" do
    css = Rails.root.join("app/assets/stylesheets/mailer.css").read

    assert_includes css, ".trix-content p {"
    assert_includes css, ".trix-content table {"
    assert_includes css, ".trix-content th,"
    assert_includes css, ".trix-content td {"
    assert_includes css, "border-collapse: collapse;"
    assert_includes css, "padding: 0.5em;"
    assert_includes css, "line-height: 1.4;"
    assert_not_includes css, "line-height: normal;"
    assert_includes css, ".trix-content li {"
  end

  test "content mail keeps a saved paragraph and a resolved highlight" do
    rendered = ActionText::Content.new(<<~HTML).to_s
      <div>Legacy note</div>
      <p>Saved note</p>
      <h2>Heading</h2>
      <span style="color: var(--highlight-3)">Painted</span>
      <p style="background-image: var(--x, url(https://evil.example/x))">Plain</p>
    HTML
    html = render_mail(rendered)

    assert_includes html, "Legacy note"
    assert_includes html, "Saved note"
    assert_includes html, "Heading"
    assert_includes html, "rgb(207, 0, 0)"
    assert_includes html, "Painted"
    assert_not_includes html, "evil.example"
    assert_not_includes html, "url("
    assert_match(/mailer.*\.css/, html)
  end

  test "member rich text h2 is a heading and h1 stays at body size" do
    css = Rails.root.join("app/assets/stylesheets/members/theme.css").read
    block = css[/\.trix-content \{([\s\S]*?)\n    \}/, 1]

    h1 = block[/\bh1 \{([\s\S]*?)\n      \}/, 1]
    h2 = block[/\bh2 \{([\s\S]*?)\n      \}/, 1]
    h3 = block[/\bh3,\n      h4 \{([\s\S]*?)\n      \}/, 1]

    assert_includes h1, "font-size: 1rem;"
    assert_includes h2, "font-size: 1.125rem;"
    assert_includes h3, "font-size: 1rem;"
    refute_includes h2, "font-size: 0.875rem;"
    refute_includes h2, "font-size: 1rem;"
  end

  private

  def render_mail(content)
    mailer = ApplicationMailer.new
    Current.org.stub(:postmark_server_token, "test-token") do
      mailer.send(
        :content_mail,
        content,
        to: "member@acme.test",
        subject: "Notes")
    end
    part = mailer.message.html_part || mailer.message
    part.body.decoded
  end
end
