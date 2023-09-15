require 'rails_helper'

describe Notifier do
  specify '.send_admin_memberships_renewal_pending_emails' do
    create(:admin, notifications: [])
    create(:admin, notifications: ['memberships_renewal_pending'])
    end_of_fiscal_year = Current.fiscal_year.end_of_year
    create(:membership, renew: true, renewal_opened_at: nil, renewed_at: nil)

    travel_to end_of_fiscal_year - 11.days do
      expect { Notifier.send_admin_memberships_renewal_pending_emails }
        .not_to change { AdminMailer.deliveries.size }
    end
    travel_to end_of_fiscal_year - 10.days do
      expect { Notifier.send_admin_memberships_renewal_pending_emails }
        .to change { AdminMailer.deliveries.size }.by(1)
    end
    travel_to end_of_fiscal_year - 7.days do
      expect { Notifier.send_admin_memberships_renewal_pending_emails }
        .not_to change { AdminMailer.deliveries.size }
    end
    travel_to end_of_fiscal_year - 4.days do
      expect { Notifier.send_admin_memberships_renewal_pending_emails }
        .to change { AdminMailer.deliveries.size }.by(1)
    end
    travel_to end_of_fiscal_year do
      expect { Notifier.send_admin_memberships_renewal_pending_emails }
        .not_to change { AdminMailer.deliveries.size }
    end
  end

  specify '.send_membership_renewal_reminder_emails' do
    Current.acp.update!(open_renewal_reminder_sent_after_in_days: 10)
    MailTemplate.find_by(title: :membership_renewal_reminder).update!(active: true)
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
    MailTemplate.find_by(title: :membership_last_trial_basket).update!(active: true)
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
      MailTemplate.find_by(title: :activity_participation_validated).update!(active: true)

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
      MailTemplate.find_by(title: :activity_participation_validated).update!(active: false)

      create(:activity_participation, :validated,
        review_sent_at: nil,
        validated_at: 1.day.ago)

      expect { Notifier.send_activity_participation_validated_emails }
        .not_to change { ActivityMailer.deliveries.size }
    end
  end

  describe '.send_activity_participation_rejected_emails' do
    specify 'send email for recently rejected participation' do
      MailTemplate.find_by(title: :activity_participation_rejected).update!(active: true)

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
      MailTemplate.find_by(title: :activity_participation_rejected).update!(active: false)

      create(:activity_participation, :rejected,
        review_sent_at: nil,
        rejected_at: 1.day.ago)

      expect { Notifier.send_activity_participation_rejected_emails }
        .not_to change { ActivityMailer.deliveries.size }
    end
  end

  describe '.send_admin_new_activity_participation_emails' do
    let(:member) { create(:member) }

    specify 'send email recently created participations in group' do
      admin = create(:admin, notifications: ['new_activity_participation'])

      date = 1.week.from_now.to_date
      activity1 = create(:activity, date: date, start_time: '8:00', end_time: '9:00')
      activity2 = create(:activity, date: date, start_time: '9:00', end_time: '10:00')

      part1 = create(:activity_participation, member: member, activity: activity1)
      part2 = create(:activity_participation, member: member, activity: activity2)

      expect { Notifier.send_admin_new_activity_participation_emails }
        .to change { ActivityMailer.deliveries.size }.by(1)

      mail = ActivityMailer.deliveries.last
      expect(mail.subject).to eq "Nouvelle participation à une ½ journée"
      expect(mail.html_part.body).to include "Horaire:</strong> 8:00-10:00"
      expect(mail.to).to eq [admin.email]

      expect(part1.reload.admins_notified_at).to be_present
      expect(part2.reload.admins_notified_at).to be_present
    end

    specify 'ignore participations older than 1 day' do
      create(:admin, notifications: ['new_activity_participation'])
      create(:activity_participation, member: member, created_at: 25.hours.ago)

      expect { Notifier.send_admin_new_activity_participation_emails }
        .not_to change { ActivityMailer.deliveries.size }
    end

    specify 'ignores already notified participations' do
      create(:admin, notifications: ['new_activity_participation'])
      create(:activity_participation, member: member, admins_notified_at: 1.hour.ago)

      expect { Notifier.send_admin_new_activity_participation_emails }
        .not_to change { ActivityMailer.deliveries.size }
    end

    specify 'only notify participation with note' do
      admin = create(:admin, notifications: ['new_activity_participation_with_note'])

      activity1 = create(:activity, date: 1.weeks.from_now)
      activity2 = create(:activity, date: 2.weeks.from_now)

      part1 = create(:activity_participation, activity: activity1, member: member)
      part2 = create(:activity_participation, :carpooling, activity: activity2, member: member,
        note: 'Super Remarque')

      expect { Notifier.send_admin_new_activity_participation_emails }
        .to change { ActivityMailer.deliveries.size }.by(1)

      mail = ActivityMailer.deliveries.last
      expect(mail.subject).to eq "Nouvelle participation à une ½ journée"
      expect(mail.html_part.body).to include "Covoiturage"
      expect(mail.html_part.body).to include "Super Remarque"
      expect(mail.to).to eq [admin.email]

      expect(part1.reload.admins_notified_at).to be_present
      expect(part2.reload.admins_notified_at).to be_present
    end

    specify 'skip admin that created the participation' do
      admin = create(:admin, notifications: ['new_activity_participation'])

      activity1 = create(:activity, date: 1.weeks.from_now)
      activity2 = create(:activity, date: 2.weeks.from_now)

      part1 = create(:activity_participation, activity: activity1, member: member,
        session: create(:session, admin: admin))
      part2 = create(:activity_participation, :carpooling, activity: activity2, member: member)

      expect { Notifier.send_admin_new_activity_participation_emails }
        .to change { ActivityMailer.deliveries.size }.by(1)

      mail = ActivityMailer.deliveries.last
      expect(mail.subject).to eq "Nouvelle participation à une ½ journée"
      expect(mail.html_part.body).to include "Covoiturage"
      expect(mail.to).to eq [admin.email]

      expect(part1.reload.admins_notified_at).to be_present
      expect(part2.reload.admins_notified_at).to be_present
    end
  end
end
