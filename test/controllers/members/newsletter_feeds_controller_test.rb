# frozen_string_literal: true

require "test_helper"

class Members::NewsletterFeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    @template = newsletter_templates(:simple)
    @template.update!(
      content: <<~LIQUID,
        {% content id: 'main', title: "News", public: true %}{% endcontent %}
      LIQUID
      feed_enabled: true)
  end

  def create_published!(subject:, body: "<p>Body</p>", at: Time.current)
    newsletter = create_newsletter(
      template: @template,
      subject: subject,
      blocks_attributes: {
        "0" => { block_id: "main", content_en: body }
      })
    travel_to(at) { newsletter.send! }
    newsletter.reload
  end

  test "returns atom feed for feed-enabled template" do
    create_published!(subject: "First public issue", body: "<p>Hello farm</p>")

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    assert_includes response.body, "<feed"
    assert_includes response.body, "First public issue"
    assert_includes response.body, "Hello farm"
    assert_includes response.body, "tag:members.acme.test,"
    assert_includes response.body, "csa:content_digest"
    assert_includes response.body, "/newsletters.atom?template_id=#{@template.id}"
    assert_includes response.body, "<author>"
    assert_includes response.body, Current.org.name
  end

  test "does not require authentication" do
    create_published!(subject: "Open")

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
  end

  test "returns not found when template missing" do
    get members_newsletter_feed_path(template_id: 0)

    assert_response :not_found
  end

  test "returns not found without template_id" do
    get "/newsletters.atom"

    assert_response :not_found
  end

  test "returns empty atom feed when no publications" do
    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    assert_includes response.body, "<feed"
    assert_includes response.body, "<author>"
    assert_includes response.body, Current.org.name
    assert_not_includes response.body, "<entry"
  end

  test "returns not found when feed disabled even if publications exist" do
    create_published!(subject: "Was public")
    assert Newsletter::Publication.for_feed(@template).exists?

    @template.update!(feed_enabled: false)

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :not_found
    # Publications remain, but the feed endpoint is gated on feed_enabled.
    assert Newsletter::Publication.where(newsletter_template_id: @template.id).exists?
  end

  test "html newsletters path stays authenticated deliveries index" do
    get members_newsletter_deliveries_path

    assert_redirected_to members_login_path
  end

  test "html newsletter show path stays authenticated delivery show" do
    get members_newsletter_delivery_path(1)

    assert_redirected_to members_login_path
  end

  test "excludes drafts scheduled withdrawn and limits to ten" do
    create_newsletter(
      template: @template,
      subject: "Draft only",
      blocks_attributes: { "0" => { block_id: "main", content_en: "<p>Draft</p>" } })

    scheduled = create_newsletter(
      template: @template,
      subject: "Scheduled only",
      scheduled_at: Date.tomorrow,
      blocks_attributes: { "0" => { block_id: "main", content_en: "<p>Later</p>" } })
    assert scheduled.scheduled?

    withdrawn = create_published!(subject: "Withdrawn issue", at: 1.hour.ago)
    withdrawn.withdraw_publication!

    11.times do |i|
      create_published!(subject: "Issue #{i}", at: Time.current + i.minutes)
    end

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
    assert_not_includes response.body, "Draft only"
    assert_not_includes response.body, "Scheduled only"
    assert_not_includes response.body, "Withdrawn issue"
    assert_includes response.body, "Issue 10"
    assert_includes response.body, "Issue 1"
    assert_not_includes response.body, "Issue 0"
  end

  test "does not leak member personalization or private template chrome" do
    @template.update!(
      content: <<~LIQUID)
        Hello {{ member.name }},
        {% content id: 'main', title: "News", public: true %}{% endcontent %}
        Signature
      LIQUID

    create_published!(
      subject: "Public only",
      body: "<p>Editorial content without member fields</p>")

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
    assert_includes response.body, "Editorial content without member fields"
    assert_not_includes response.body, "John Doe"
    assert_not_includes response.body, "Hello"
    assert_not_includes response.body, "Signature"
    assert_not_includes response.body, "jane@doe.com"
    assert_not_includes response.body, "unsubscribe"
  end

  test "rewrites real active storage blob paths to absolute urls" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "logo.png",
      content_type: "image/png")
    blob_path = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)

    create_published!(
      subject: "With image",
      body: %(<p>Photo <img src="#{blob_path}" alt="logo"></p>))

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
    assert_match %r{src="https?://[^"]+/rails/active_storage/}, response.body
    assert_includes response.body, blob.filename.to_s
  end

  test "includes newsletter file attachments as atom enclosures" do
    newsletter = create_newsletter(
      template: @template,
      subject: "With file",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>See attached recipe</p>" }
      })
    attachment = Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture("logo.png")),
      filename: "farm-photo.png")
    newsletter.update!(attachments: [ attachment ])
    newsletter.send!

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
    assert_includes response.body, 'rel="enclosure"'
    assert_includes response.body, 'type="image/png"'
    assert_includes response.body, 'title="farm-photo.png"'
    assert_match %r{href="https?://[^"]+/rails/active_storage/}, response.body
  end

  test "scopes entries to the requested template only" do
    other = Newsletter::Template.create!(
      title: "Other feed template",
      content: "{% content id: 'main', public: true %}{% endcontent %}",
      feed_enabled: true)

    create_published!(subject: "From primary template", body: "<p>Primary</p>")

    other_newsletter = create_newsletter(
      template: other,
      subject: "From other template",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Other body</p>" }
      })
    other_newsletter.send!

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
    assert_includes response.body, "From primary template"
    assert_includes response.body, "Primary"
    assert_not_includes response.body, "From other template"
    assert_not_includes response.body, "Other body"
  end

  test "supports conditional get with public cache headers" do
    create_published!(subject: "Cacheable")

    get members_newsletter_feed_path(template_id: @template.id)
    assert_response :success
    assert_match(/public/i, response.headers["Cache-Control"].to_s)
    etag = response.headers["ETag"]
    assert etag.present?

    get members_newsletter_feed_path(template_id: @template.id),
      headers: { "If-None-Match" => etag }

    assert_response :not_modified
  end

  test "if-modified-since does not 304 after withdrawing the newest entry" do
    create_published!(subject: "Older issue", at: 2.hours.ago)
    newest = create_published!(subject: "Newest issue", at: 1.hour.ago)

    get members_newsletter_feed_path(template_id: @template.id)
    assert_response :success
    assert_includes response.body, "Newest issue"
    last_modified = response.headers["Last-Modified"]
    assert last_modified.present?

    travel 1.minute
    newest.withdraw_publication!

    get members_newsletter_feed_path(template_id: @template.id),
      headers: { "If-Modified-Since" => last_modified }

    assert_response :success
    assert_includes response.body, "Older issue"
    assert_not_includes response.body, "Newest issue"
  end

  test "escapes html content instead of using fragile cdata" do
    create_published!(
      subject: "Escaped content",
      body: "<p>Code sample ]]> and more</p>")

    get members_newsletter_feed_path(template_id: @template.id)

    assert_response :success
    assert_not_includes response.body, "<![CDATA["
    # HTML then XML escaping: ]]> → ]]&gt; → ]]&amp;gt;
    assert_includes response.body, "]]&amp;gt;"
    assert_includes response.body, "Code sample"
  end

  test "serves requested locale content and falls back to default locale" do
    org(languages: %w[en fr])
    @template.update!(
      title_en: "Simple EN",
      title_fr: "Simple FR",
      content_en: <<~LIQUID,
        {% content id: 'main', title: "News", public: true %}{% endcontent %}
      LIQUID
      content_fr: <<~LIQUID,
        {% content id: 'main', title: "Nouvelles", public: true %}{% endcontent %}
      LIQUID
      feed_enabled: true)

    newsletter = create_newsletter(
      template: @template,
      subject_en: "English issue",
      subject_fr: "Numéro français",
      blocks_attributes: {
        "0" => {
          block_id: "main",
          content_en: "<p>English body</p>",
          content_fr: "<p>Corps français</p>"
        }
      })
    newsletter.send!

    get members_newsletter_feed_path(template_id: @template.id)
    assert_response :success
    assert_includes response.body, "English issue"
    assert_includes response.body, "English body"
    assert_not_includes response.body, "Numéro français"
    assert_includes response.body, "hreflang=\"fr\""
    assert_includes response.body, "locale=fr"

    get members_newsletter_feed_path(template_id: @template.id, locale: "fr")
    assert_response :success
    assert_includes response.body, "Numéro français"
    assert_includes response.body, "Corps français"
    assert_includes response.body, "Simple FR"
    assert_includes response.body, "locale=fr"
    assert_not_includes response.body, "English body"

    get members_newsletter_feed_path(template_id: @template.id, locale: "xx")
    assert_response :success
    assert_includes response.body, "English issue"
    assert_includes response.body, "English body"
  end

  test "does not persist members portal locale cookie from feed locale param" do
    org(languages: %w[en fr])
    @template.update!(
      title_en: "Simple EN",
      title_fr: "Simple FR",
      content_en: <<~LIQUID,
        {% content id: 'main', title: "News", public: true %}{% endcontent %}
      LIQUID
      content_fr: <<~LIQUID,
        {% content id: 'main', title: "Nouvelles", public: true %}{% endcontent %}
      LIQUID
      feed_enabled: true)

    newsletter = create_newsletter(
      template: @template,
      subject_en: "English issue",
      subject_fr: "Numéro français",
      blocks_attributes: {
        "0" => {
          block_id: "main",
          content_en: "<p>English body</p>",
          content_fr: "<p>Corps français</p>"
        }
      })
    newsletter.send!

    get members_newsletter_feed_path(template_id: @template.id, locale: "fr")

    assert_response :success
    assert_includes response.body, "Numéro français"
    assert_nil cookies[:locale]
  end
end
