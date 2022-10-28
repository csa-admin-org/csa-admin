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
end
