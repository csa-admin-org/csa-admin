require 'rails_helper'

describe Admin do
  describe '#right?' do
    it 'gives all rights to superadmin' do
      admin = Admin.new(rights: 'superadmin')

      expect(admin.right?('none')).to eq true
      expect(admin.right?('readonly')).to eq true
      expect(admin.right?('standard')).to eq true
      expect(admin.right?('admin')).to eq true
      expect(admin.right?('superadmin')).to eq true
    end

    it 'gives just none right to none' do
      admin = Admin.new(rights: 'none')

      expect(admin.right?('none')).to eq true
      expect(admin.right?('readonly')).to eq false
      expect(admin.right?('standard')).to eq false
      expect(admin.right?('admin')).to eq false
      expect(admin.right?('superadmin')).to eq false
    end

    it 'gives none, readonly and standard rights to standard' do
      admin = Admin.new(rights: 'standard')

      expect(admin.right?('none')).to eq true
      expect(admin.right?('readonly')).to eq true
      expect(admin.right?('standard')).to eq true
      expect(admin.right?('admin')).to eq false
      expect(admin.right?('superadmin')).to eq false
    end
  end

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
end
