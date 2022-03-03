require 'rails_helper'

describe Permission do
  describe 'rights=' do
    specify 'can only writes editable features' do
      permission = Permission.new(rights: {
        admin: :write,
        member: :write
      })
      expect(permission.rights).to eq('member' => 'write')
    end
  end

  specify 'superadmin' do
    permission = Permission.superadmin
    expect(permission.rights).to be_empty
    expect(permission.superadmin?).to be_truthy
    expect(permission.can_write?(:acp)).to be_truthy
    expect(permission.can_write?(:comment)).to be_truthy
    expect(permission.can_write?(:basket_size)).to be_truthy
    expect(permission.can_destroy?).to be_falsey
    expect(permission.can_update?).to be_falsey
  end
end
