require 'rails_helper'

describe Newsletter::Delivery do
  let(:template) { create(:newsletter_template) }
  let(:newsletter) {
    create(:newsletter,
      template: template,
      audience: 'member_state::pending',
      subject: 'Subject {{ member.name }}',
      blocks_attributes: {
        '0' => { block_id: 'main', content_fr: 'Block {{ member.name }}' }
      }
    )
  }

  specify 'store emails on creation' do
    member = create(:member, emails: 'john@bob.com, jane@bob.com')
    create(:email_suppression, email: 'john@bob.com', stream_id: 'broadcast')

    delivery = Newsletter::Delivery.create!(newsletter: newsletter, member: member)
    expect(delivery.emails).to eq %w[jane@bob.com]
    expect(delivery.suppressed_emails).to eq %w[john@bob.com]
  end

  specify 'deliver newsletter' do
    # simulate newsletter sent
    newsletter.update!(template_contents: template.contents)

    member = create(:member, name: 'Bob', emails: 'john@bob.com, jane@bob.com')
    delivery = Newsletter::Delivery.create!(newsletter: newsletter, member: member)

    expect { delivery.deliver! }
      .to change { ActionMailer::Base.deliveries.count }.by(2)
      .and change { delivery.reload.delivered_at }.from(nil)

    expect(delivery.subject).to eq 'Subject Bob'
    expect(delivery.content).to include "Salut Bob,"
    expect(delivery.content).to include "Block Bob"

    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly(
      %w[john@bob.com], %w[jane@bob.com])

    email = ActionMailer::Base.deliveries.first
    expect(email.from).to eq ['info@ragedevert.ch']
    expect(email.subject).to eq 'Subject Bob'
    mail_body = email.parts.map(&:body).join
    expect(mail_body).to include "Salut Bob,"
    expect(mail_body).to include "Block Bob"
    expect(mail_body).to include "Au plaisir,\r\n<br />Rage de Vert</p>"
  end

  specify 'deliver newsletter with custom from' do
    newsletter.update!(
      # simulate newsletter sent
      template_contents: template.contents,
      from: 'contact@ragedevert.ch')

    member = create(:member)
    delivery = Newsletter::Delivery.create!(newsletter: newsletter, member: member)

    expect { delivery.reload.deliver! }
      .to change { ActionMailer::Base.deliveries.count }

    email = ActionMailer::Base.deliveries.first
    expect(email.from).to eq ['contact@ragedevert.ch']
  end

  specify 'deliver newsletter with custom signature' do
    Current.acp.update! email_signature: 'Signature'
    newsletter.update!(
      # simulate newsletter sent
      template_contents: template.contents,
      signature: 'Au plaisir')

    member = create(:member, emails: 'john@doe.com')
    delivery = Newsletter::Delivery.create!(newsletter: newsletter, member: member)

    expect { delivery.reload.deliver! }
      .to change { ActionMailer::Base.deliveries.count }

    email = ActionMailer::Base.deliveries.first
    mail_body = email.parts.map(&:body).join
    expect(mail_body).not_to include 'Signature'
    expect(mail_body).to include "Au plaisir</p>"
  end

  specify 'deliver newsletter with attachments' do
    attachment = Newsletter::Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture('qrcode-test.png')),
      filename: 'qrcode-test.png')
    newsletter.update! attachments: [attachment]

    # simulate newsletter sent
    newsletter.update!(template_contents: template.contents)

    member = create(:member, name: 'Bob', emails: 'john@bob.com, jane@bob.com')
    delivery = Newsletter::Delivery.create!(newsletter: newsletter, member: member)

    expect { delivery.deliver! }
      .to change { ActionMailer::Base.deliveries.count }.by(2)
      .and change { delivery.reload.delivered_at }.from(nil)

    mail = ActionMailer::Base.deliveries.first
    expect(mail[:message_stream].to_s).to eq 'broadcast'

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq 'qrcode-test.png'
    expect(attachment.content_type).to eq 'image/png'
  end
end
