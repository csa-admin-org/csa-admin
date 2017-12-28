require 'rails_helper'

describe Ability do
  let(:ability) { Ability.new(admin) }

  context 'superadmin admin' do
    let(:admin) { create(:admin, rights: 'superadmin') }

    specify { expect(ability.can?(:create, Member)).to be true }
    specify { expect(ability.can?(:update, Member)).to be true }
    specify { expect(ability.can?(:destroy, Member)).to be true }
    specify { expect(ability.can?(:validate, Member)).to be true }
    specify { expect(ability.can?(:remove_from_waiting_list, Member)).to be true }
    specify { expect(ability.can?(:put_back_to_waiting_list, Member)).to be true }
  end

  context 'admin admin' do
    let(:admin) { create(:admin, rights: 'admin') }

    specify { expect(ability.can?(:create, Member)).to be true }
    specify { expect(ability.can?(:update, Member)).to be true }
    specify { expect(ability.can?(:destroy, Member)).to be true }
    specify { expect(ability.can?(:validate, Member)).to be true }
    specify { expect(ability.can?(:remove_from_waiting_list, Member)).to be true }
    specify { expect(ability.can?(:put_back_to_waiting_list, Member)).to be true }
  end
end
