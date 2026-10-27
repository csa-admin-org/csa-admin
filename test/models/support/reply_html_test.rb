# frozen_string_literal: true

require "test_helper"

class Support::ReplyHtmlTest < ActiveSupport::TestCase
  test "keeps apple mail quotes that are part of the reply" do
    html = <<~HTML
      <html><body>
        <div>Salut David,</div>
        <div><blockquote type="cite"><div>Question about the invoice?</div></blockquote></div>
        <div>The invoice was rebuilt.</div>
        <blockquote type="cite"><div>Could we force the annual number?</div></blockquote>
        <div>A checkbox would do that.</div>
        <div>++</div>
        <div>Thibaud</div>
        <div><br><blockquote type="cite"><div>On 9 Oct 2026, at 08:17, CSA Admin wrote:</div><div>Old thread</div></blockquote></div>
      </body></html>
    HTML

    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      extracted = Support::ReplyHtml.extract(html)
      reply, original = Support::ReplyHtml.split_cited(html)

      assert_includes extracted, "Question about the invoice"
      assert_includes extracted, "Could we force"
      assert_includes extracted, "checkbox"
      assert_not_includes extracted, "Old thread"
      assert_not_includes extracted, "Thibaud"
      assert_includes reply, "Question about the invoice"
      assert_includes reply, "Could we force"
      assert_not_includes reply, "Old thread"
      assert_includes original, "Old thread"
      assert_not_includes original, "Question about the invoice"
    end
  end

  test "collapses doubled breaks and drops spacers against a quote" do
    html = <<~HTML
      <html><body>
        <div>Salut,</div>
        <div><br></div>
        <div><br></div>
        <div><blockquote type="cite"><div>Question one?</div></blockquote></div>
        <div><br></div>
        <div>Answer one.</div>
        <div><br></div>
        <div>Answer two.</div>
        <div><br></div>
        <div><br></div>
        <blockquote type="cite"><div>Question two?</div></blockquote>
        <div><br></div>
        <div>Closing.</div>
      </body></html>
    HTML

    extracted = Support::ReplyHtml.extract(html)
    root = Nokogiri::HTML::DocumentFragment.parse(extracted)
    spacers = root.css("div").select { |node| node.inner_html == "<br>" }

    assert_includes extracted, "Question one"
    assert_includes extracted, "Question two"
    assert_equal 1, spacers.size
    assert_equal "Answer one.", spacers.first.previous_element.text
    assert_equal "Answer two.", spacers.first.next_element.text
  end

  test "keeps an intent cite that sits just before the signature" do
    html = <<~HTML
      <html><body>
        <div>Answer.</div>
        <blockquote type="cite"><div>Last question?</div></blockquote>
        <div>++</div>
        <div>Thibaud</div>
      </body></html>
    HTML

    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      extracted = Support::ReplyHtml.extract(html)
      reply, original = Support::ReplyHtml.split_cited(html)

      assert_includes extracted, "Last question"
      assert_not_includes extracted, "Thibaud"
      assert_includes reply, "Last question"
      assert_nil original
    end
  end

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

  test "split_cited returns the reply and original as two fragments" do
    html = <<~HTML
      <html><body>
        <p>Here is the answer</p>
        <blockquote type="cite">
          <p>On Mon, Jane Doe wrote:</p>
          <p>Hello from the member</p>
        </blockquote>
      </body></html>
    HTML

    reply, original = Support::ReplyHtml.split_cited(html)

    assert_includes reply, "Here is the answer"
    assert_not_includes reply, "Hello from the member"
    assert_includes original, "Hello from the member"
    assert_not_includes original, "On Mon"
    assert_not_includes original, "Here is the answer"
  end

  test "split_cited treats a thunderbird cite prefix as the original header" do
    html = <<~HTML
      <html><body>
        <p>Here is the answer</p>
        <div class="moz-cite-prefix">On Monday, Jane Doe wrote:<br></div>
        <blockquote type="cite">
          <p>Hello from the member</p>
        </blockquote>
      </body></html>
    HTML

    reply, original = Support::ReplyHtml.split_cited(html)

    assert_includes reply, "Here is the answer"
    assert_not_includes reply, "Hello from the member"
    assert_not_includes reply, "On Monday"
    assert_includes original, "Hello from the member"
    assert_not_includes original, "On Monday"
  end

  test "split_cited skips a header-only cite and keeps the following original" do
    html = <<~HTML
      <html><body>
        <div>Here is the answer</div>
        <div>
          <blockquote type="cite">On 13 Oct 2026, at 06:19, Jane Doe wrote:<br><br></blockquote>
        </div>
        <blockquote type="cite">
          <div>Hello from the member</div>
          <div><img alt="image.png" src="cid:shot@mail"></div>
          <div>---</div>
          <div>Jane Doe</div>
        </blockquote>
      </body></html>
    HTML

    reply, original = Support::ReplyHtml.split_cited(html)

    assert_includes reply, "Here is the answer"
    assert_not_includes reply, "Hello from the member"
    assert_not_includes reply, "On 13 Oct"
    assert_includes original, "Hello from the member"
    assert_includes original, "image.png"
    assert_not_includes original, "On 13 Oct"
    assert_not_includes original, "Here is the answer"
  end

  test "drops a proton mail quote block" do
    html = <<~HTML
      <div>Yes super ! Merci :)</div>
      <div>Au plaisir !</div>
      <div class="protonmail_quote">
        -------- Original Message --------<br>
        On Tuesday, 09/22/26 at 13:12 CSA Admin &lt;ticket@support.csa-admin.org&gt; wrote:
      </div>
    HTML

    extracted = Support::ReplyHtml.extract(html)

    assert_includes extracted, "Yes super"
    assert_includes extracted, "Au plaisir"
    assert_not_includes extracted, "Original Message"
    assert_not_includes extracted, "wrote"
  end

  test "present drops a stored proton quote and a leftover separator" do
    html = <<~HTML
      <div>Yes super ! Merci :)</div>
      <br>
      <div class="protonmail_quote">-------- Original Message --------</div>
      <p>——– Original Message ——–</p>
    HTML

    presented = Support::ReplyHtml.present(html)

    assert_includes presented, "Yes super"
    assert_not_includes presented, "Original Message"
    assert_not_includes presented, "protonmail_quote"
    assert_not_includes presented, "<br"
  end

  test "present drops a proton sent-from line and an indented sign-off" do
    signoff = Support::ReplyHtml.present(<<~HTML)
      <div class="trix-content">
        <p>Oui bien sûr !</p>
        <pre><code>    Arthur Pasquier
</code></pre>
      </div>
    HTML
    sent = Support::ReplyHtml.present(<<~HTML)
      <div class="trix-content">
        <p>Pour lui c’est une habitude.</p>
        <p>Arthur</p>
        <p>Sent from <a href="https://proton.me/mail/home">Proton Mail</a> for Android.</p>
        <p>——– Original Message ——–</p>
      </div>
    HTML

    assert_includes signoff, "Oui bien sûr"
    assert_not_includes signoff, "Pasquier"
    assert_not_includes signoff, "<pre"
    assert_includes sent, "habitude"
    assert_includes sent, "Arthur"
    assert_not_includes sent, "Proton Mail"
    assert_not_includes sent, "Original Message"
  end

  test "drops inbound font styles but keeps the reply" do
    html = <<~HTML
      <html><body>
        <div style="font-family: Arial, sans-serif; font-size: 14px;">top - merci beaucoup !</div>
        <blockquote type="cite"><div>quoted</div></blockquote>
      </body></html>
    HTML

    extracted = Support::ReplyHtml.extract(html)

    assert_includes extracted, "merci beaucoup"
    assert_not_includes extracted, "font-size"
    assert_not_includes extracted, "font-family"
    assert_not_includes extracted, "style="
    assert_not_includes extracted, "quoted"
  end

  test "present drops a stored client font size" do
    html = %(<div style="font-family: Arial, sans-serif; font-size: 14px;">top - merci beaucoup ! manuel</div>)

    presented = Support::ReplyHtml.present(html)

    assert_includes presented, "merci beaucoup"
    assert_not_includes presented, "font-size"
    assert_not_includes presented, "style="
  end

  test "display collapses doubled breaks and spacers around a kept quote" do
    html = <<~HTML
      <div>Answer.</div>
      <div><br></div>
      <div></div>
      <div><br></div>
      <blockquote type="cite"><div>Quoted question?</div></blockquote>
      <br>
      <div>Next.</div>
      <div><br></div>
      <div><br></div>
      <div>After.</div>
    HTML

    [ Support::ReplyHtml.strip_styles(html), Support::ReplyHtml.present(html) ].each do |shown|
      root = Nokogiri::HTML::DocumentFragment.parse(shown)
      spacers = root.element_children.select { |node|
        node.name == "br" || node.inner_html == "<br>" || node.inner_html.blank?
      }

      assert_includes shown, "Quoted question"
      assert_equal 1, spacers.size
      assert_equal "Next.", spacers.first.previous_element.text
      assert_equal "After.", spacers.first.next_element.text
    end
  end

  test "keeps a trix paragraph break and folds a longer run" do
    html = <<~HTML
      <div>Hello.<br><br>Thanks.<br>Sam</div>
      <div><br></div>
      <br><br>
      <div>Next.</div>
      <div>Run.<br><br><br><br>After.</div>
    HTML

    shown = Support::ReplyHtml.present(html)
    root = Nokogiri::HTML::DocumentFragment.parse(shown)
    hello = root.at("div")

    assert_equal %w[br br br], hello.element_children.map(&:name)
    assert_equal "Thanks.", hello.element_children[1].next.text.strip
    assert_equal "Sam", hello.element_children[2].next.text.strip
    assert_equal "<br>", root.element_children[1].inner_html
    assert_equal "Next.", root.element_children[2].text
    assert_equal 2, root.element_children.last.css("br").size
  end

  test "keeps styles inside a liquid code fence" do
    html = %(<pre style="white-space: pre"><code>{% if member.salary_basket %}</code></pre>)

    extracted = Support::ReplyHtml.extract(html)

    assert_includes extracted, "white-space"
    assert_includes extracted, "salary_basket"
  end

  test "drops a gmail signature and the dash delimiter" do
    html = <<~HTML
      <div dir="ltr">Nothing urgent.</div>
      <div>warm regards,&nbsp;</div>
      <div>Sam</div>
      <br><div><br clear="all"></div>
      <span class="gmail_signature_prefix">-- </span><br>
      <div dir="ltr" class="gmail_signature" data-smartmail="gmail_signature">
        <div><b>Green Farm</b></div>
        <div><a href="https://example.test">Website</a> | Newsletter</div>
      </div>
    HTML

    presented = Support::ReplyHtml.present(html)
    extracted = Support::ReplyHtml.extract(html)

    assert_includes presented, "warm regards"
    assert_includes presented, "Sam"
    assert_not_includes presented, "Green Farm"
    assert_not_includes presented, "Website"
    assert_not_includes presented, "--"
    assert_not_includes extracted, "Green Farm"
    assert_includes extracted, "Nothing urgent"
  end

  test "drops a gmail signature that has no dash delimiter" do
    html = <<~HTML
      <div dir="auto">have a good evening!</div>
      <div dir="auto">Sam</div>
      <div><br clear="all"><div>
        <div dir="ltr" class="gmail_signature" data-smartmail="gmail_signature">
          <div><b>Green Farm</b></div>
          <div>Nico Street 20</div>
        </div>
      </div></div>
    HTML

    quote = '<div class="gmail_quote">On Wed, Sam wrote:<blockquote>Earlier</blockquote></div>'
    presented = Support::ReplyHtml.present(html)
    reply, original = Support::ReplyHtml.split_cited(html + quote)

    assert_includes presented, "good evening"
    assert_includes presented, "Sam"
    assert_not_includes presented, "Green Farm"
    assert_not_includes presented, "Nico Street"
    assert_includes reply, "good evening"
    assert_not_includes reply, "Green Farm"
    assert_not_includes reply, "Earlier"
    assert_includes original, "Earlier"
  end

  test "drops an infomaniak image signature and its address block" do
    html = <<~HTML
      <div>Thanks for the help.</div>
      <div>Sam</div>
      <div data-ik-opengraph-ignore="">
        <p><b>Green Farm</b> nearby produce</p>
        <div><b>1 Farm Road<br>000.000.00.00<br><a href="https://example.test">example.test</a></b></div>
        <div><img src="https://workspace.storage.infomaniak.com/signature/logo" alt="sign">&nbsp;</div>
      </div>
    HTML
    rendered = html.gsub(/ data-ik-opengraph-ignore=""/, "")

    [ html, rendered ].each do |source|
      shown = Support::ReplyHtml.present(source)

      assert_includes shown, "Thanks for the help"
      assert_includes shown, "Sam"
      assert_not_includes shown, "Green Farm"
      assert_not_includes shown, "Farm Road"
      assert_not_includes shown, "infomaniak"
    end
  end

  test "keeps a reply image that is not a signature" do
    html = <<~HTML
      <div>See the invoice.</div>
      <div><img src="https://admin.example.test/rails/active_storage/blobs/shot.png" alt="shot"></div>
    HTML

    shown = Support::ReplyHtml.present(html)

    assert_includes shown, "shot.png"
    assert_includes shown, "invoice"
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
