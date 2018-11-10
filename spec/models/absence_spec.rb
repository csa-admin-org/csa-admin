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

  describe 'notify_new_absence_to_admins' do
    it 'notifies admin with new_absence notifications on when created' do
      admin1 = create(:admin, notifications: ['new_absence'])
      admin2 = create(:admin, notifications: ['new_absence'])
      admin3 = create(:admin, notifications: [])

      absence = create(:absence, admin: admin1)

      expect(email_adapter.deliveries.size).to eq 1
      expect(email_adapter.deliveries.first).to match(hash_including(
        from: Current.acp.email_default_from,
        to: admin2.email,
        template: 'absence-new-fr',
        template_data: hash_including(
          admin_name: admin1.name,
          member_name: absence.member.name,
          started_on: I18n.l(absence.started_on),
          ended_on: I18n.l(absence.ended_on)
        )))
    end
  end
end
