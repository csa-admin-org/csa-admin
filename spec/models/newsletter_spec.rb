# frozen_string_literal: true

require "rails_helper"

describe Newsletter do
  let(:template) {
    create(:newsletter_template,
      content_fr: <<~LIQUID,
        {% content id: 'first', title: 'First FR' %}
          FIRST CONTENT FR
        {% endcontent %}
        {% content id: 'second' %}
          SECOND CONTENT FR
        {% endcontent %}
      LIQUID
      content_de: <<~LIQUID)
        {% content id: 'first', title: 'First DE' %}
          FIRST CONTENT DE
        {% endcontent %}
        {% content id: 'second' %}
          SECOND CONTENT DE
        {% endcontent %}
      LIQUID
  }

  specify "validate from hostname" do
    Current.org.update!(email_default_host: "https://membres.ragedevert.ch")

    newsletter = build(:newsletter, from: "info@rave.ch")
    expect(newsletter).not_to have_valid(:from)

    newsletter = build(:newsletter, from: "contact@ragedevert.ch")
    expect(newsletter).to have_valid(:from)

    newsletter = build(:newsletter, from: nil)
    expect(newsletter).to have_valid(:from)

    newsletter = build(:newsletter, from: "")
    expect(newsletter).to have_valid(:from)
  end

  specify "validate subject liquid" do
    newsletter = build(:newsletter, template: template,
      subject: "Foo {{ ")

    expect(newsletter).not_to have_valid(:subject_fr)
    expect(newsletter.errors[:subject_fr])
      .to include "Liquid syntax error: Variable '{{' was not properly terminated with regexp: /\\}\\}/"
  end

  specify "validate subject html" do
    newsletter = build(:newsletter, template: template,
      subject: "Foo <i>bar")

    expect(newsletter).not_to have_valid(:subject_fr)
    expect(newsletter.errors[:subject_fr])
      .to include "HTML error at line 1: Generic parser"
  end

  specify "validate at least content must be present" do
    newsletter = build(:newsletter, template: template,
      blocks_attributes: {
        "0" => { block_id: "first", content_fr: "" },
        "1" => { block_id: "second", content_fr: "" }
      })

    expect(newsletter).not_to have_valid(:blocks)
  end

  specify "validate block content liquid" do
    newsletter = build(:newsletter, template: template,
      blocks_attributes: {
        "0" => { block_id: "first", content_fr: "Foo {{" }
      })

    expect(newsletter.relevant_blocks.first).not_to have_valid(:content_fr)
    expect(newsletter.relevant_blocks.first.errors[:content_fr])
      .to include "Liquid syntax error: Variable '{{' was not properly terminated with regexp: /\\}\\}/"
  end

  specify "mailpreview" do
    Current.org.update! email_signature: "Signature"
    newsletter = build(:newsletter, template: template,
      subject: "Ma Super Newsletter",
      blocks_attributes: {
        "0" => { block_id: "first", content_fr: "Hello {{ member.name }}" },
        "1" => { block_id: "second", content_fr: "Youpla Boom" }
      })
    newsletter.liquid_data_preview_yamls = {
      "fr" => <<~YAML
        member:
          name: Bob Dae
        subject: Ma Newsletter
      YAML
    }

    mail = newsletter.mail_preview("fr")
    expect(mail).to include "Ma Super Newsletter</h1>"
    expect(mail).to include "First FR</h2>"
    expect(mail).to include "Hello Bob Dae"
    expect(mail).to include "Youpla Boom"
    expect(mail).to include "Signature"
  end

  specify "mailpreview with custom signature" do
    Current.org.update! email_signature: "Signature"
    newsletter = build(:newsletter,
      template: template,
      signature: "Au plaisir")

    mail = newsletter.mail_preview("fr")
    expect(mail).not_to include "Signature"
    expect(mail).to include "Au plaisir"
  end

  specify "mailpreview is using persisted template content and preview data once sent" do
    newsletter = build(:newsletter, template: template,
      subject: "Ma Super Newsletter",
      blocks_attributes: {
        "0" => { block_id: "first", content_fr: "Hello {{ member.name }}" },
        "1" => { block_id: "second", content_fr: "Youpla Boom" }
      })
    preview_yamls = {
      "fr" => <<~YAML
        member:
          name: Bob Dae
        subject: Ma Newsletter
      YAML
    }
    newsletter.liquid_data_preview_yamls = preview_yamls

    mail = newsletter.mail_preview("fr")
    expect(mail).to include "Ma Super Newsletter</h1>"
    expect(mail).to include "First FR</h2>"
    expect(mail).to include "Hello Bob Dae"
    expect(mail).to include "Youpla Boom"

    newsletter.send!

    template.update! content_fr: <<~LIQUID
      {% content id: 'first', title: 'First NEW FR' %}
        FIRST CONTENT FR
      {% endcontent %}
      NEW LINE
      {% content id: 'second' %}
        SECOND CONTENT FR
      {% endcontent %}
    LIQUID

    newsletter = Newsletter.last # hard reload

    expect(newsletter[:liquid_data_preview_yamls]).to eq preview_yamls

    mail = newsletter.mail_preview("fr")
    expect(mail).to include "Ma Super Newsletter</h1>"
    expect(mail).to include "First FR</h2>"
    expect(mail).not_to include "NEW LINE"
    expect(mail).to include "Hello Bob Dae"
    expect(mail).to include "Youpla Boom"
  end

  describe "#send!" do
    let(:newsletter) {
      create(:newsletter,
        audience: "member_state::pending",
        blocks_attributes: {
          "0" => { block_id: "main", content_fr: "Hello {{ member.name }}" }
        }
      )
    }

    specify "send newsletter" do
      create(:member, name: "Doe", emails: "john@doe.com, jane@doe.com")
      create(:member, name: "Bob", emails: "john@bob.com, jane@bob.com")
      create(:email_suppression,
        id: 123,
        email: "john@bob.com",
        stream_id: "broadcast",
        reason: "HardBounce")

      expect(newsletter.audience_segment.members.count).to eq 2
      expect(newsletter.audience_segment.emails).to contain_exactly *%w[
        jane@doe.com
        john@doe.com
        jane@bob.com
      ]
      expect(newsletter.audience_segment.suppressed_emails).to eq %w[john@bob.com]
      expect(newsletter.template_contents).to be_empty
      expect(newsletter[:liquid_data_preview_yamls]).to be_empty
      expect(newsletter.audience_names).to be_empty

      expect {
        perform_enqueued_jobs { newsletter.send! }
      }
        .to change { newsletter.deliveries.count }.by(4)
        .and change { newsletter.sent_at }.from(nil)
        .and change { ActionMailer::Base.deliveries.count }.by(3)

      expect(newsletter.deliveries.ignored.count).to eq 1
      expect(newsletter.deliveries.ignored.first).to have_attributes(
        email: "john@bob.com",
        email_suppression_ids: [ 123 ],
        email_suppression_reasons: [ "HardBounce" ])

      newsletter = Newsletter.last # hard reload
      expect(newsletter).to be_sent
      expect(newsletter.members.count).to eq 2
      expect(newsletter.deliveries.processing.pluck(:email)).to contain_exactly *%w[
        jane@doe.com
        john@doe.com
        jane@bob.com
      ]
      expect(newsletter.deliveries.ignored.pluck(:email)).to eq %w[john@bob.com]
      expect(newsletter.template_contents).to eq newsletter.template.contents
      expect(newsletter[:liquid_data_preview_yamls]).not_to be_empty
      expect(newsletter.audience_names).to eq(
        "fr" => "Membres: À valider")
    end
  end
end
