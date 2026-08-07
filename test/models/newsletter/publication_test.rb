# frozen_string_literal: true

require "test_helper"

class Newsletter::PublicationTest < ActiveSupport::TestCase
  setup do
    @template = newsletter_templates(:simple)
    @template.update!(
      content: <<~LIQUID,
        Hello {{ member.name }},
        {% content id: 'main', title: "News", public: true %}
          Editorial only
        {% endcontent %}
        Signature
      LIQUID
      feed_enabled: true)
  end

  test "creates publication on send when feed enabled and public blocks present" do
    newsletter = create_newsletter(
      template: @template,
      subject: "Weekly notes",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Field report from the farm</p>" }
      })

    assert_difference -> { Newsletter::Publication.count }, 1 do
      newsletter.send!
    end

    publication = newsletter.reload.publication
    assert_not_nil publication
    assert_equal @template.id, publication.newsletter_template_id
    assert_equal newsletter.sent_at.to_i, publication.published_at.to_i
    assert_nil publication.withdrawn_at
    assert_equal "Weekly notes", publication.title
    assert_includes publication.summary, "Field report"
    assert_equal 1, publication.sections.size
    assert_equal "main", publication.sections.first["id"]
    assert_equal "News", publication.sections.first["title"]
    assert_includes publication.sections.first["html"], "Field report"
    assert publication.content_digest.present?
    assert_equal %w[en], publication.payload.keys
    assert_equal "Weekly notes", publication.payload.dig("en", "title")
  end

  test "stores all organization languages in the publication payload" do
    org(languages: %w[en fr])
    @template.update!(
      title_en: "Simple",
      title_fr: "Simple",
      content_en: <<~LIQUID,
        {% content id: 'main', title: "News", public: true %}{% endcontent %}
      LIQUID
      content_fr: <<~LIQUID,
        {% content id: 'main', title: "Nouvelles", public: true %}{% endcontent %}
      LIQUID
      feed_enabled: true)

    newsletter = create_newsletter(
      template: @template,
      subject_en: "Weekly notes",
      subject_fr: "Notes de la semaine",
      blocks_attributes: {
        "0" => {
          block_id: "main",
          content_en: "<p>Field report from the farm</p>",
          content_fr: "<p>Rapport des champs</p>"
        }
      })

    newsletter.send!
    publication = newsletter.reload.publication

    assert_equal %w[en fr].sort, publication.payload.keys.sort
    assert_equal "Weekly notes", publication.title("en")
    assert_equal "Notes de la semaine", publication.title("fr")
    assert_includes publication.content_html(locale: "en"), "Field report"
    assert_includes publication.content_html(locale: "fr"), "Rapport des champs"
    assert_equal "Nouvelles", publication.sections("fr").first["title"]
    assert_equal "News", publication.sections("en").first["title"]
  end

  test "falls back to default locale when requested language is missing" do
    org(languages: %w[en fr])
    @template.update!(
      title_en: "Simple",
      title_fr: "Simple",
      content_en: <<~LIQUID,
        {% content id: 'main', public: true %}{% endcontent %}
      LIQUID
      content_fr: <<~LIQUID,
        {% content id: 'main', public: true %}{% endcontent %}
      LIQUID
      feed_enabled: true)

    newsletter = create_newsletter(
      template: @template,
      subject_en: "English only body",
      subject_fr: "French subject unused",
      blocks_attributes: {
        "0" => {
          block_id: "main",
          content_en: "<p>Only English content</p>",
          content_fr: ""
        }
      })
    newsletter.send!
    publication = newsletter.reload.publication

    assert_equal %w[en], publication.payload.keys
    assert_equal "English only body", publication.title("fr")
    assert_includes publication.content_html(locale: "fr"), "Only English content"
  end

  test "does not create publication when feed disabled" do
    @template.update!(feed_enabled: false)
    newsletter = create_newsletter(
      template: @template,
      subject: "Private",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Secret</p>" }
      })

    assert_no_difference -> { Newsletter::Publication.count } do
      newsletter.send!
    end
    assert_nil newsletter.reload.publication
  end

  test "does not create publication when public blocks are empty" do
    @template.update!(
      content: <<~LIQUID,
        {% content id: 'main', public: true %}{% endcontent %}
        {% content id: 'private' %}{% endcontent %}
      LIQUID
      feed_enabled: true)
    newsletter = create_newsletter(
      template: @template,
      subject: "Empty public",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "" },
        "1" => { block_id: "private", content_en: "<p>Member only {{ member.name }}</p>" }
      })

    assert_no_difference -> { Newsletter::Publication.count } do
      newsletter.send!
    end
    assert newsletter.reload.sent?
    assert_nil newsletter.publication
  end

  test "send fails closed when public liquid references member data" do
    newsletter = create_newsletter(
      template: @template,
      subject: "Safe draft body",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Editorial ok</p>" }
      })
    # Block Liquid validation only checks syntax; undefined vars fail at public projection.
    Newsletter::Block.find_by!(newsletter: newsletter, block_id: "main").update!(
      content_en: "<p>Hello {{ member.name }}</p>")
    newsletter.reload

    assert_raises(Newsletter::PublicProjection::Error) do
      newsletter.send!
    end
    assert_not newsletter.reload.sent?
    assert_nil newsletter.publication
  end

  test "draft validation fails when public liquid is invalid" do
    newsletter = build_newsletter(
      template: @template,
      subject: "Broken draft",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>{{ membership.id }}</p>" }
      })

    assert_not newsletter.valid?
    assert_equal 1, newsletter.errors[:base].size
    assert_includes newsletter.errors[:base].first, "Public feed content"
  end

  test "draft validation fails when subject liquid is member-specific" do
    newsletter = build_newsletter(
      template: @template,
      subject: "Hello {{ member.name }}",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Editorial ok</p>" }
      })

    assert_not newsletter.valid?
    assert_equal 1, newsletter.errors[:base].size
  end

  test "send fails closed when subject liquid is member-specific" do
    newsletter = create_newsletter(
      template: @template,
      subject: "Safe subject",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Editorial ok</p>" }
      })
    newsletter.update_columns(subjects: { "en" => "Hello {{ member.name }}" })
    newsletter.reload

    assert_raises(Newsletter::PublicProjection::Error) do
      newsletter.send!
    end
    assert_not newsletter.reload.sent?
    assert_nil newsletter.publication
  end

  test "public projection never includes member name, template chrome, or unsubscribe tokens" do
    newsletter = create_newsletter(
      template: @template,
      subject: "Safe subject",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Only public text from #{Current.org.name}</p>" }
      })
    newsletter.send!
    html = newsletter.publication.content_html

    assert_not_includes html, "John"
    assert_not_includes html, "Doe"
    assert_not_includes html, "Hello"
    assert_not_includes html, "Signature"
    assert_not_includes html, "unsubscribe"
    assert_not_includes html, members(:john).emails
  end

  test "content_digest changes when image markup changes with identical plain text" do
    first = create_newsletter(
      template: @template,
      subject: "Image digest",
      blocks_attributes: {
        "0" => {
          block_id: "main",
          content_en: %(<p>Photo <img src="/rails/active_storage/blobs/redirect/one/a.jpg" alt="shot"></p>)
        }
      })
    first.send!
    digest_one = first.publication.content_digest

    second = create_newsletter(
      template: @template,
      subject: "Image digest",
      blocks_attributes: {
        "0" => {
          block_id: "main",
          content_en: %(<p>Photo <img src="/rails/active_storage/blobs/redirect/two/b.jpg" alt="shot"></p>)
        }
      })
    second.send!

    assert_not_equal digest_one, second.publication.content_digest
  end

  test "content_html rewrites real active storage blob paths to absolute urls" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "logo.png",
      content_type: "image/png")
    blob_path = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)

    newsletter = create_newsletter(
      template: @template,
      subject: "With real image",
      blocks_attributes: {
        "0" => {
          block_id: "main",
          content_en: %(<p>Photo <img src="#{blob_path}" alt="logo"></p>)
        }
      })
    newsletter.send!
    html = newsletter.publication.content_html(
      url_options: { host: "members.acme.test", protocol: "https" })

    assert_includes html, "src=\"https://members.acme.test#{blob_path}\""
    assert_includes html, "/rails/active_storage/"
    assert_not_includes html, "admin.acme.test"
  end

  test "withdraw removes from active scope" do
    newsletter = create_newsletter(
      template: @template,
      subject: "To withdraw",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Published once</p>" }
      })
    newsletter.send!
    publication = newsletter.publication

    assert_includes Newsletter::Publication.for_feed(@template), publication
    newsletter.withdraw_publication!
    assert publication.reload.withdrawn?
    assert_not_includes Newsletter::Publication.for_feed(@template).to_a, publication
  end

  test "feed limits to ten newest active publications" do
    11.times do |i|
      newsletter = create_newsletter(
        template: @template,
        subject: "Issue #{i}",
        blocks_attributes: {
          "0" => { block_id: "main", content_en: "<p>Body #{i}</p>" }
        })
      travel_to(Time.current + i.minutes) { newsletter.send! }
    end

    feed = Newsletter::Publication.for_feed(@template)
    assert_equal 10, feed.size
    assert_equal "Issue 10", feed.first.title
    assert_equal "Issue 1", feed.last.title
  end

  test "atom_id is snapshotted at create and does not follow host renames" do
    newsletter = create_newsletter(
      template: @template,
      subject: "Stable id",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Hi</p>" }
      })
    newsletter.send!
    publication = newsletter.publication
    expected = "tag:#{Tenant.members_host},#{publication.published_at.year}:newsletter/#{newsletter.id}"

    assert_equal expected, publication.atom_id
    assert_equal expected, publication.read_attribute(:atom_id)

    publication.update_columns(atom_id: "tag:archived.example,2024:newsletter/#{newsletter.id}")
    assert_equal "tag:archived.example,2024:newsletter/#{newsletter.id}", publication.reload.atom_id
  end

  test "publication records are not updatable or destroyable via ability lifecycle" do
    newsletter = create_newsletter(
      template: @template,
      subject: "Locked",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Hi</p>" }
      })
    newsletter.send!
    publication = newsletter.publication

    assert_not publication.can_update?
    assert_not publication.can_destroy?
  end

  test "title is rendered subject only without liquid source fallback" do
    newsletter = create_newsletter(
      template: @template,
      subject: "{{ organization.name }}",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Body</p>" }
      })
    newsletter.send!

    assert_equal Current.org.name, newsletter.publication.title
    assert_not_includes newsletter.publication.title, "{{"
  end

  test "sanitizes script tags and event handlers from public html" do
    newsletter = create_newsletter(
      template: @template,
      subject: "Sanitize me",
      blocks_attributes: {
        "0" => {
          block_id: "main",
          content_en: %(<p onclick="alert(1)">Hi</p><script>alert(1)</script><img src="x" onerror="alert(1)">)
        }
      })
    newsletter.send!
    html = newsletter.publication.sections.first["html"]

    assert_includes html, "Hi"
    assert_not_includes html, "<script"
    assert_not_includes html, "onclick"
    assert_not_includes html, "onerror"
  end

  test "content_html puts id only on section wrapper" do
    newsletter = create_newsletter(
      template: @template,
      subject: "Section ids",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Body</p>" }
      })
    newsletter.send!
    html = newsletter.publication.content_html

    assert_includes html, %(<section id="main">)
    assert_includes html, "<h2>News</h2>"
    assert_not_includes html, %(<h2 id="main">)
  end

  test "unwraps real action text attachments into feed html" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "logo.png",
      content_type: "image/png")
    attach_html = <<~HTML
      <div>
        <action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/png" url="#{Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)}" filename="logo.png" presentation="gallery">
          <figure class="attachment">
            <img src="#{Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)}" alt="logo">
          </figure>
        </action-text-attachment>
      </div>
    HTML

    newsletter = create_newsletter(
      template: @template,
      subject: "Action text image",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: attach_html }
      })
    newsletter.send!
    html = newsletter.publication.content_html(
      url_options: { host: "members.acme.test", protocol: "https" })

    assert_not_includes html, "action-text-attachment"
    assert_includes html, "/rails/active_storage/"
    assert_includes html, "https://members.acme.test"
    assert_not_includes html, "admin.acme.test"
    assert_includes html, "logo"
  end

  test "newsletter file attachments are snapshotted in the publication payload" do
    newsletter = create_newsletter(
      template: @template,
      subject: "With attachment",
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Editorial</p>" }
      })
    attachment = Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture("logo.png")),
      filename: "farm-photo.png")
    newsletter.update!(attachments: [ attachment ])
    newsletter.send!

    publication = newsletter.publication
    html = publication.content_html
    attachments = publication.attachments

    assert_includes html, "Editorial"
    assert_not_includes html, "farm-photo.png"
    assert_equal 1, attachments.size
    assert_equal "farm-photo.png", attachments.first["filename"]
    assert_equal "image/png", attachments.first["content_type"]
    assert attachments.first["signed_id"].present?
    assert_match(
      %r{\Ahttps://},
      publication.attachment_url(
        attachments.first,
        url_options: { host: "members.acme.test", protocol: "https" }))
  end
end
