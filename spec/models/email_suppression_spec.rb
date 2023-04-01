require 'rails_helper'

describe EmailSuppression do
  def suppress!(stream_id, email, reason, origin)
    create(:email_suppression,
      stream_id: stream_id,
      email: email,
      reason: reason,
      origin: origin)
  end

  specify '.sync_postmark!' do
    travel_to '2020-01-08 10:00:00 +0100' do
      suppress!('outbound', 'a@b.com', 'HardBounce', 'Recipient')
      postmark_client.dump_suppressions_response = [
        {
          email_address: 'a@b.com',
          suppression_reason: 'HardBounce',
          origin: 'Recipient',
          created_at: Time.current.to_s
        }, {
          email_address: 'd@f.com',
          suppression_reason: 'SpamComplaint',
          origin: 'Customer',
          created_at: 1.hour.ago
        }
      ]
    end
    EmailSuppression.first.unsuppress!

    expect { EmailSuppression.sync_postmark! }
      .to change { EmailSuppression.outbound.count }.by(1)
    expect(EmailSuppression.outbound.active.first).to have_attributes(
      email: 'd@f.com',
      reason: 'SpamComplaint',
      origin: 'Customer',
      created_at: Time.parse('2020-01-08 09:00:00 +0100'))
  end

  describe '.unsuppress!' do
    before do
      suppress!('outbound', 'a@b.com', 'HardBounce', 'Recipient')
      suppress!('outbound', 'd@f.com', 'HardBounce', 'Recipient')
      suppress!('outbound', 'z@y.com', 'ManualSuppression', 'Customer')
      suppress!('broadcast', 'a@b.com', 'HardBounce', 'Recipient')
    end

    specify 'unsuppress all suppressable suppression with give email' do
      expect {
        EmailSuppression.unsuppress!('a@b.com',
          stream_id: 'outbound',
          origin: 'Recipient')
      }.to change { EmailSuppression.active.count }.by(-1)
      expect(EmailSuppression.active.outbound.where(email: 'a@b.com')).to be_empty
      expect(postmark_client.calls).to eq [
        [:delete_suppressions, 'outbound', 'a@b.com']
      ]
    end

    specify 'skips undeletable emails' do
      expect {
        EmailSuppression.unsuppress!('z@y.com',
          stream_id: 'outbound',
          origin: 'Recipient')
      }.not_to change { EmailSuppression.active.count }
      expect(postmark_client.calls).to be_empty
    end
  end

  describe '.suppress!' do
    before do
      suppress!('outbound', 'a@b.com', 'HardBounce', 'Recipient')
      suppress!('broadcast', 'a@b.com', 'HardBounce', 'Recipient')
    end

    specify 'create new suppression' do
      expect {
        EmailSuppression.suppress!('x@y.com',
          stream_id: 'outbound',
          origin: 'Customer',
          reason: 'ManualSuppression')
      }.to change { EmailSuppression.active.count }.by(1)
      expect(EmailSuppression.active.find_by(email: 'x@y.com')).to have_attributes(
        stream_id: 'outbound',
        origin: 'Customer',
        reason: 'ManualSuppression')
      expect(postmark_client.calls).to eq [
        [:create_suppressions, 'outbound', 'x@y.com']
      ]
    end

    specify 'skips already suppressed email' do
      expect {
        EmailSuppression.suppress!('a@b.com',
          stream_id: 'outbound',
          origin: 'Customer',
          reason: 'ManualSuppression')
      }.not_to change { EmailSuppression.active.count }
      expect(postmark_client.calls).to be_empty
    end
  end

  specify 'notifies admins when created' do
    admin = create(:admin, notifications: ['new_email_suppression'])
    create(:admin, notifications: [])

    suppress!('outbound', 'a@b.com', 'HardBounce', 'Recipient')

    expect(AdminMailer.deliveries.size).to eq 1
    mail = AdminMailer.deliveries.last
    expect(mail.subject).to eq 'Email rejeté (HardBounce)'
    expect(mail.to).to eq [admin.email]
    expect(mail.html_part.body).to include admin.name
  end


  specify 'do not notify manual suppression to admins when created' do
    admin = create(:admin, notifications: ['new_email_suppression'])
    create(:admin, notifications: [])

    suppress!('outbound', 'a@b.com', 'ManualSuppression', 'Customer')

    expect(AdminMailer.deliveries.size).to be_zero
  end
end
