require 'rails_helper'

describe Absence, freeze: '2021-06-15' do
  describe 'validations' do
    it 'validates started_on and ended_on dates when submited by member' do
      absence = Absence.new(
        started_on: 6.days.from_now,
        ended_on: 2.years.from_now)

      expect(absence).not_to have_valid(:started_on)
      expect(absence).not_to have_valid(:ended_on)
    end

    it 'does not validate started_on and ended_on dates when submited by admin' do
      absence = Absence.new(
        admin: Admin.new,
        started_on: Date.today,
        ended_on: 2.years.from_now)

      expect(absence).to have_valid(:started_on)
      expect(absence).to have_valid(:ended_on)
    end
  end

  describe 'update_memberships!' do
    it 'updates absent baskets state' do
      member = create(:member)
      current_membership =
        create(:membership, member: member, deliveries_count: 40)
      future_membership =
        create(:membership, :next_year, member: member, deliveries_count: 40)

      expect(current_membership.baskets.absent.count).to eq 0
      expect(future_membership.baskets.absent.count).to eq 0

      end_of_year = Date.today.end_of_year
      create(:absence,
        admin: Admin.new,
        member: member,
        started_on: end_of_year - 4.months,
        ended_on: end_of_year + 1.month)

      expect(current_membership.reload.baskets.absent.count).to eq 6
      expect(future_membership.reload.baskets.absent.count).to eq 4
    end

    it 'updates membership price when absent baskets are not billed' do
      current_acp.update!(absences_billed: false)

      member = create(:member)
      membership =
        create(:membership, member: member, basket_price: 10, deliveries_count: 40)
      end_of_year = Date.today.end_of_year

      expect {
        create(:absence,
          admin: Admin.new,
          member: member,
          started_on: end_of_year - 4.months,
          ended_on: end_of_year)
      }.to change { membership.reload.price }.from(40 * 10).to(34 * 10)
    end
  end

  describe 'notify_new_absence_to_admins' do
    it 'notifies admin with new_absence notifications on when created', sidekiq: :inline do
      admin1 = create(:admin, notifications: ['new_absence'])
      admin2 = create(:admin, notifications: ['new_absence'])
      create(:admin, notifications: ['new_absence_with_note'])
      create(:admin, notifications: [])

      absence = create(:absence, admin: admin1, note: ' ')

      expect(AdminMailer.deliveries.size).to eq 1
      mail = AdminMailer.deliveries.last
      expect(mail.subject).to eq 'Nouvelle absence'
      expect(mail.to).to eq [admin2.email]
      body = mail.html_part.body
      expect(body).to include admin2.name
      expect(body).to include absence.member.name
      expect(body).to include I18n.l(absence.started_on)
      expect(body).to include I18n.l(absence.ended_on)
      expect(body).not_to include 'Remarque du membre:'
    end

    specify 'only notifies admin with new_absence_with_note notifications when note is present', sidekiq: :inline do
      admin1 = create(:admin, notifications: ['new_absence_with_note'])
      admin2 = create(:admin, notifications: ['new_absence_with_note'])
      create(:admin, notifications: [])
      absence = create(:absence, admin: admin1, note: 'Une Super Remarque!')

      expect(AdminMailer.deliveries.size).to eq 1
      mail = AdminMailer.deliveries.last
      expect(mail.subject).to eq 'Nouvelle absence'
      expect(mail.to).to eq [admin2.email]
      body = mail.html_part.body
      expect(body).to include admin2.name
      expect(body).to include absence.member.name
      expect(body).to include I18n.l(absence.started_on)
      expect(body).to include I18n.l(absence.ended_on)
      expect(body).to include 'Remarque du membre:'
      expect(body).to include 'Une Super Remarque!'
    end
  end
end
