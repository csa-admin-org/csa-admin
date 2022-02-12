require 'rails_helper'

describe Notifier do
  specify '.send_membership_renewal_reminder_emails' do
    Current.acp.update!(open_renewal_reminder_sent_after_in_days: 10)
    MailTemplate.create! title: :membership_renewal_reminder, active: true
    next_fy = Current.acp.fiscal_year_for(Date.today.year + 1)
    create(:delivery, date: next_fy.beginning_of_year)
    member = create(:member, emails: 'john@doe.com')

    create(:membership, renewal_opened_at: nil)
    create(:membership, renewal_opened_at: 10.days.ago).update_column(:renewed_at, 10.days.ago)
    create(:membership, renewal_opened_at: 10.days.ago, member: member)
    create(:membership, renewal_opened_at: 10.days.ago, renewal_reminder_sent_at: 1.minute.ago)
    create(:membership, :last_year, renewal_opened_at: 10.days.ago)

    expect { Notifier.send_membership_renewal_reminder_emails }
      .to change { MembershipMailer.deliveries.size }.by(1)

    mail = MembershipMailer.deliveries.last
    expect(mail.subject).to eq 'Renouvellement de votre abonnement (Rappel)'
    expect(mail.to).to eq ['john@doe.com']
  end

  specify '.send_membership_last_trial_basket_emails' do
    Current.acp.update!(trial_basket_count: 2)
    MailTemplate.create! title: :membership_last_trial_basket, active: true
    travel_to '2021-05-01' do
      create(:delivery, date: '2021-05-01')
      create(:delivery, date: '2021-05-02')
      create(:delivery, date: '2021-05-03')
      create(:delivery, date: '2021-05-04')
    end
    travel_to '2021-05-03' do
      member = create(:member, emails: 'john@doe.com')

      create(:membership, started_on: '2021-05-01')
      create(:membership, started_on: '2021-05-03')
      create(:membership, started_on: '2021-05-02', member: member)
      create(:membership, started_on: '2021-05-02', ended_on: '2021-05-03')
      create(:membership, started_on: '2021-05-02', last_trial_basket_sent_at: 1.minute.ago)

      expect { Notifier.send_membership_last_trial_basket_emails }
        .to change { MembershipMailer.deliveries.size }.by(1)

      mail = MembershipMailer.deliveries.last
      expect(mail.subject).to eq "Dernier panier à l'essai!"
      expect(mail.to).to eq ['john@doe.com']
    end
  end

  describe '.send_activity_participation_validated_emails' do
    specify 'send email for recently validated participation' do
      MailTemplate.create! title: :activity_participation_validated, active: true

      create(:activity_participation, :validated,
        review_sent_at: nil,
        validated_at: 1.day.ago,
        member: create(:member, emails: 'john@snow.com'))
      create(:activity_participation, :rejected,
        review_sent_at: nil,
        rejected_at: 1.day.ago)
      create(:activity_participation, :validated,
        validated_at: 1.day.ago,
        review_sent_at: Time.current)
      create(:activity_participation, :validated,
        validated_at: 4.days.ago)

      expect { Notifier.send_activity_participation_validated_emails }
        .to change { ActivityMailer.deliveries.size }.by(1)

      mail = ActivityMailer.deliveries.last
      expect(mail.subject).to eq "Activité validée 🎉"
      expect(mail.to).to eq ['john@snow.com']
    end

    specify 'does not send email when template is not active' do
      MailTemplate.create! title: :activity_participation_validated, active: false

      create(:activity_participation, :validated,
        review_sent_at: nil,
        validated_at: 1.day.ago)

      expect { Notifier.send_activity_participation_validated_emails }
        .not_to change { ActivityMailer.deliveries.size }
    end
  end

  describe '.send_activity_participation_rejected_emails' do
    specify 'send email for recently rejected participation' do
      MailTemplate.create! title: :activity_participation_rejected, active: true

      create(:activity_participation, :rejected,
        review_sent_at: nil,
        rejected_at: 1.day.ago,
        member: create(:member, emails: 'john@snow.com'))
      create(:activity_participation, :validated,
        review_sent_at: nil,
        validated_at: 1.day.ago)
      create(:activity_participation, :rejected,
        rejected_at: 1.day.ago,
        review_sent_at: Time.current)
      create(:activity_participation, :rejected,
        rejected_at: 4.days.ago)

      expect { Notifier.send_activity_participation_rejected_emails }
        .to change { ActivityMailer.deliveries.size }.by(1)

      mail = ActivityMailer.deliveries.last
      expect(mail.subject).to eq "Activité refusée 😬"
      expect(mail.to).to eq ['john@snow.com']
    end

    specify 'does not send email when template is not active' do
      MailTemplate.create! title: :activity_participation_rejected, active: false

      create(:activity_participation, :rejected,
        review_sent_at: nil,
        rejected_at: 1.day.ago)

      expect { Notifier.send_activity_participation_rejected_emails }
        .not_to change { ActivityMailer.deliveries.size }
    end
  end
end
