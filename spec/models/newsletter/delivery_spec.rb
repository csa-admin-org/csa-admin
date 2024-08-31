# frozen_string_literal: true

require "rails_helper"

describe Newsletter::Delivery do
  let(:template) { create(:newsletter_template) }
  let(:newsletter) {
    create(:newsletter,
      template: template,
      audience: "member_state::pending",
      subject: "Subject {{ member.name }}",
      blocks_attributes: {
        "0" => { block_id: "main", content_fr: "Block {{ member.name }}" }
      }
    )
  }

  specify "store emails on creation", sidekiq: :inline do
    member = create(:member, emails: "john@bob.com, jane@bob.com")
    create(:email_suppression,
      id: 512312,
      email: "john@bob.com",
      stream_id: "broadcast",
      reason: "ManualSuppression")
    create(:email_suppression,
      id: 153123,
      email: "john@bob.com",
      stream_id: "broadcast",
      reason: "HardBounce")

    expect {
      Newsletter::Delivery.create_for!(newsletter, member)
    }.to change(Newsletter::Delivery, :count).by(2)

    expect(Newsletter::Delivery.processing.first).to have_attributes(
      email: "jane@bob.com",
      email_suppression_ids: [])
    expect(Newsletter::Delivery.ignored.first).to have_attributes(
      email: "john@bob.com",
      email_suppression_ids: [ 512312, 153123 ],
      email_suppression_reasons: [ "ManualSuppression", "HardBounce" ])
  end

  specify "store delivery even for members without email" do
    member = create(:member, emails: "")

    expect {
      Newsletter::Delivery.create_for!(newsletter, member)
    }.to change(Newsletter::Delivery, :count).by(1)

    expect(Newsletter::Delivery.first).to have_attributes(
      email: nil,
      email_suppression_ids: [])
  end

  specify "send newsletter", sidekiq: :inline do
    # simulate newsletter sent
    newsletter.update!(template_contents: template.contents)
    member = create(:member, name: "Bob", emails: "john@bob.com, jane@bob.com")

    expect { Newsletter::Delivery.create_for!(newsletter, member) }
      .to change { ActionMailer::Base.deliveries.count }.by(2)

    delivery = Newsletter::Delivery.first
    expect(delivery.subject).to eq "Subject Bob"
    expect(delivery.content).to include "Salut Bob,"
    expect(delivery.content).to include "Block Bob"

    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly(
      %w[john@bob.com], %w[jane@bob.com])

    email = ActionMailer::Base.deliveries.first
    expect(email.from).to eq [ "info@ragedevert.ch" ]
    expect(email.subject).to eq "Subject Bob"
    mail_body = email.parts.map(&:body).join
    expect(mail_body).to include "Salut Bob,"
    expect(mail_body).to include "Block Bob"
    expect(mail_body).to include "Au plaisir,\r\n<br />Rage de Vert</p>"
  end

  specify "send newsletter with custom from", sidekiq: :inline do
    newsletter.update!(
      # simulate newsletter sent
      template_contents: template.contents,
      from: "contact@ragedevert.ch")
    member = create(:member)

    expect { Newsletter::Delivery.create_for!(newsletter, member) }
      .to change { ActionMailer::Base.deliveries.count }

    email = ActionMailer::Base.deliveries.first
    expect(email.from).to eq [ "contact@ragedevert.ch" ]
  end

  specify "send newsletter with custom signature", sidekiq: :inline do
    Current.org.update! email_signature: "Signature"
    newsletter.update!(
      # simulate newsletter sent
      template_contents: template.contents,
      signature: "Au plaisir")
    member = create(:member, emails: "john@doe.com")

    expect { Newsletter::Delivery.create_for!(newsletter, member) }
      .to change { ActionMailer::Base.deliveries.count }

    email = ActionMailer::Base.deliveries.first
    mail_body = email.parts.map(&:body).join
    expect(mail_body).not_to include "Signature"
    expect(mail_body).to include "Au plaisir</p>"
  end

  specify "send newsletter with attachments", sidekiq: :inline do
    attachment = Newsletter::Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture("qrcode-test.png")),
      filename: "qrcode-test.png")
    newsletter.update! attachments: [ attachment ]

    # simulate newsletter sent
    newsletter.update!(template_contents: template.contents)

    member = create(:member, name: "Bob", emails: "john@bob.com, jane@bob.com")

    expect { Newsletter::Delivery.create_for!(newsletter, member) }
      .to change { ActionMailer::Base.deliveries.count }.by(2)

    mail = ActionMailer::Base.deliveries.first
    expect(mail[:message_stream].to_s).to eq "broadcast"

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq "qrcode-test.png"
    expect(attachment.content_type).to eq "image/png"
  end
end
