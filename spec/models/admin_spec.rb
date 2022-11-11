require 'rails_helper'

describe Admin do
  it 'deletes sessions when destroyed' do
    admin = create(:admin)
    session = create(:session, admin: admin)

    expect {
      admin.destroy!
    }.to change(Session, :count).by(-1)
  end

  it 'sets latest_update_read on create' do
    admin = create(:admin, latest_update_read: nil)
    expect(admin.latest_update_read).to eq Update.all.first.name
  end

  specify 'email=' do
    admin = Admin.new(email: 'Thibaud@Thibaud.GG ')
    expect(admin.email).to eq 'thibaud@thibaud.gg'
  end

  describe '.notify!' do
    specify 'with suppressed email' do
      admin = create(:admin, notifications: ['new_absence'])
      create(:email_suppression, email: admin.email)

      expect {
        Admin.notify!(:new_absence)
      }.not_to change(ActionMailer::Base.deliveries, :count)
    end
  end
end
