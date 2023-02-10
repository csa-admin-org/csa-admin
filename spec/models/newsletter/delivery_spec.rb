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
    expect(email.subject).to eq 'Subject Bob'
    mail_body = email.parts.map(&:body).join
    expect(mail_body).to include "Salut Bob,"
    expect(mail_body).to include "Block Bob"
  end
end
