# frozen_string_literal: true

require "test_helper"

class Support::ReplyHtmlTest < ActiveSupport::TestCase
  test "keeps apple mail new content and drops cite blockquote" do
    html = <<~HTML
      <html><body>
        <div>Voici le lien</div>
        <blockquote type="cite"><div>quoted</div></blockquote>
      </body></html>
    HTML

    extracted = Support::ReplyHtml.extract(html)

    assert_includes extracted, "Voici le lien"
    assert_not_includes extracted, "quoted"
  end

  test "cuts at the wrap marker" do
    html = <<~HTML
      <div>New answer</div>
      <p id="csa-admin-reply-above">marker</p>
      <div>old thread</div>
    HTML

    extracted = Support::ReplyHtml.extract(html)

    assert_includes extracted, "New answer"
    assert_not_includes extracted, "old thread"
    assert_not_includes extracted, "csa-admin-reply-above"
  end

  test "drops a trailing untyped quote that repeats the thread" do
    html = <<~HTML
      <p>Mmm, étrange en effet.</p>
      <blockquote>
        <p>On 24 Jun 2026, at 21:16, Jane wrote:</p>
        <p>Facture n 1167</p>
      </blockquote>
    HTML

    extracted = Support::ReplyHtml.extract(html)

    assert_includes extracted, "étrange"
    assert_not_includes extracted, "Facture n 1167"
  end

  test "cuts wrap-shaped payload at the table marker and drops the quoted previous" do
    html = <<~HTML
      <html><body>
        <p>My answer</p>
        <table id="csa-admin-reply-above"><tr><td>marker</td></tr></table>
        <blockquote type="cite">
          <p>Jane, 13 Sep:</p>
          <p>old thread</p>
        </blockquote>
      </body></html>
    HTML

    extracted = Support::ReplyHtml.extract(html)

    assert_includes extracted, "My answer"
    assert_not_includes extracted, "old thread"
    assert_not_includes extracted, "csa-admin-reply-above"
    assert_not_includes extracted, "Jane, 13 Sep"
  end

  test "keeps a cited original when converting informal mail" do
    html = <<~HTML
      <html><body>
        <p>Here is the answer</p>
        <blockquote type="cite"><div>Hello from the member</div></blockquote>
      </body></html>
    HTML

    extracted = Support::ReplyHtml.extract(html, keep_cited: true)

    assert_includes extracted, "Here is the answer"
    assert_includes extracted, "Hello from the member"
    assert_includes extracted, "blockquote"
  end

  test "strips a trailing operator signature" do
    html = <<~HTML
      <html><body>
        <p>Voici le lien</p>
        <p>++</p>
        <p>Thibaud</p>
        <blockquote type="cite"><div>quoted</div></blockquote>
      </body></html>
    HTML

    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      extracted = Support::ReplyHtml.extract(html)

      assert_includes extracted, "Voici le lien"
      assert_not_includes extracted, "++"
      assert_not_includes extracted, "Thibaud"
      assert_not_includes extracted, "quoted"
    end
  end
end
