require 'rails_helper'

describe Absence do
  describe 'validations' do
    it 'validates started_on and ended_on dates when submited by member' do
      absence = Absence.new(
        started_on: Date.today,
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
      current_membership = create(:membership, member: member)
      future_membership = create(:membership, :next_year, member: member)

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
      membership = create(:membership, member: member, basket_price: 10)
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
    it 'notifies admin with new_absence notifications on when created' do
      admin1 = create(:admin, notifications: ['new_absence'])
      admin2 = create(:admin, notifications: ['new_absence'])
      create(:admin, notifications: [])

      absence = create(:absence, admin: admin1)

      expect(email_adapter.deliveries.size).to eq 1
      expect(email_adapter.deliveries.first).to match(hash_including(
        from: Current.acp.email_default_from,
        to: admin2.email,
        template: 'admin-absence-new',
        template_data: hash_including(
          admin_name: admin1.name,
          member_name: absence.member.name,
          started_on: I18n.l(absence.started_on),
          ended_on: I18n.l(absence.ended_on)
        )))
    end
  end
end
