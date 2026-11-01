# frozen_string_literal: true

require "test_helper"

class LexxyEditorTest < ActiveSupport::TestCase
  test "to_editor_html keeps stored fragments and liquid tokens" do
    content = ActionText::Content.new(<<~HTML)
      <div>Hello <strong>farm</strong></div>
      <ol><li>One</li><li>Two</li></ol>
      <div>{{ member.name }} {% if member.name %}yes{% endif %}</div>
    HTML

    html = content.to_editor_html

    assert_includes html, "<div>Hello"
    assert_includes html, "<strong>farm</strong>"
    assert_includes html, "<ol>"
    assert_not_includes html, "<p><ol>"
    assert_includes html, "{{ member.name }}"
    assert_includes html, "{% if member.name %}"
    assert_equal "", ActionText::Content.new("").to_editor_html
  end

  test "underline is stripped and the text is kept" do
    html = ActionTextHtml.strip_underline('<p>See <u class="lexxy-content__underline">this</u> and <ul><li>keep</li></ul></p>')
    rendered = ActionText::Content.new("<p><u>this</u> <s>old</s></p>").to_s

    assert_equal "<p>See this and <ul><li>keep</li></ul></p>", html
    assert_includes rendered, "this"
    assert_not_includes rendered, "<u"
    assert_includes rendered, "<s>old</s>"

    kept = ActionTextHtml.strip_underline('<span class="foo lexxy-content__underline bar">x</span>')
    assert_equal '<span class="foo bar">x</span>', kept
    prose = ActionTextHtml.strip_underline("<p>mention lexxy-content__underline here</p>")
    assert_includes prose, "lexxy-content__underline"
  end

  test "render drops video, audio, and embed and keeps table structure" do
    html = ActionText::Content.new(<<~HTML).to_s
      <table><caption>cap</caption><tfoot><tr><td>foot</td></tr></tfoot></table>
      <video src="https://example.com/a.mp4"></video>
      <audio src="https://example.com/a.mp3"></audio>
      <embed src="https://example.com/a.swf">
      <source src="https://example.com/a.mp4">
    HTML
    tags = ActionText::ContentHelper.allowed_tags

    assert_includes html, "<caption>cap</caption>"
    assert_includes html, "<tfoot>"
    assert_includes html, "<td>foot</td>"
    assert_not_includes html, "<video"
    assert_not_includes html, "<audio"
    assert_not_includes html, "<embed"
    assert_not_includes html, "<source"
    assert_not_includes tags, "video"
    assert_not_includes tags, "embed"
    assert_includes tags, "tfoot"
  end

  test "a nested url inside var is dropped and a known highlight is kept" do
    html = ActionText::Content.new(<<~HTML).to_s
      <p style="background-image: var(--x, url(https://evil.example/x))">hi</p>
      <p style="background:linear-gradient(url(https://evil.example/g))">fade</p>
      <img style="background-image: var(--x, url(https://evil.example/pixel))" src="https://example.com/a.png">
      <span style="color: var(--highlight-1)">c</span>
    HTML
    feed = ActionController::Base.helpers.sanitize(
      ActionTextHtml.resolve_highlights(html),
      tags: Newsletter::PublicProjection::ALLOWED_TAGS,
      attributes: Newsletter::PublicProjection::ALLOWED_ATTRIBUTES)

    assert_not_includes html, "url("
    assert_not_includes html, "var("
    assert_includes html, "rgb(136, 118, 38)"
    assert_not_includes feed, "evil.example"
    assert_includes feed, "rgb(136, 118, 38)"
  end

  test "a lexxy image url wraps the rendered image" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "plot.png",
      content_type: "image/png")
    html = ActionText::Content.new(%(<action-text-attachment sgid="#{blob.attachable_sgid}" url="https://example.com/plot" alt="plot"></action-text-attachment>)).to_s

    assert_includes html, 'href="https://example.com/plot"'
    assert_includes html, 'alt="plot"'
  end

  test "strike and table survive action text render" do
    html = ActionText::Content.new("<p><s>old</s></p><table><tr><td>cell</td></tr></table>").to_s

    assert_includes html, "<s>old</s>"
    assert_includes html, "<table>"
    assert_includes html, "<td>cell</td>"
    assert_includes html, "trix-content"
  end

  test "lexxy paragraph keeps a heading and drops a script" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "plot.png",
      content_type: "image/png")
    Current.org.member_form_subtitle = <<~HTML
      <p>Saved note</p>
      <h2>Heading</h2>
      <script>alert(1)</script>
      <action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/png">
        <img src="/rails/active_storage/blobs/redirect/signed/plot.png" alt="plot">
      </action-text-attachment>
    HTML
    Current.org.save!

    rendered = Current.org.member_form_subtitle

    assert_includes rendered, "<p>Saved note</p>"
    assert_includes rendered, "<h2>Heading</h2>"
    assert_includes rendered, "trix-content"
    assert_not_includes rendered, "<script"
    assert_includes rendered, "plot.png"
    assert_includes rendered, "<img"
    assert_no_match(%r{<action-text-attachment\b[^>]*>\s*</action-text-attachment>}i, rendered)

    mailed = ActionTextHtml.unwrap_attachments(rendered)
    assert_includes mailed, "<img"
    assert_includes mailed, "plot.png"
    assert_no_match(/<action-text-attachment/i, mailed)
  end

  test "marshal signed attachment does not raise and is not rewritten" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "plot.png",
      content_type: "image/png")
    sgid = marshal_attachable_sgid(blob)
    html = %(<div>See <action-text-attachment sgid="#{sgid}" content-type="image/png"></action-text-attachment></div>)
    content = ActionText::Content.new(html)

    assert_equal "See [plot.png]", content.to_plain_text.strip
    assert_includes content.to_editor_html, "action-text-attachment"
    assert_includes content.to_editor_html, sgid

    Current.org.member_form_subtitle = html
    Current.org.save!
    stored = Current.org.rich_text_member_form_subtitle_en.body.to_html

    assert_includes stored, sgid
  end

  private

  def marshal_attachable_sgid(record)
    gid = record.to_global_id.to_s
    secret = Rails.application.key_generator.generate_key("signed_global_ids")
    verifier = GlobalID::Verifier.new(secret, serializer: :marshal)
    signed = verifier.generate(gid, purpose: "attachable")
    assert signed.start_with?("BAh"), "expected a Marshal SGID, got #{signed[0, 8]}"
    signed
  end
end
