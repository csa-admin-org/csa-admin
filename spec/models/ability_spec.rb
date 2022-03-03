require 'rails_helper'

describe Ability do
  let(:ability) { Ability.new(admin) }

  context 'superadmin' do
    let(:admin) { create(:admin, permission: Permission.superadmin) }

    specify { expect(ability.can?(:read, ACP)).to be_truthy }
    specify { expect(ability.can?(:update, Current.acp)).to be_truthy }

    specify { expect(ability.can?(:manage, Admin)).to be_truthy }
    specify { expect(ability.can?(:destroy, admin)).to be_falsey }

    specify { expect(ability.can?(:manage, ActiveAdmin::Comment)).to be_truthy }

    specify { expect(ability.can?(:create, Absence)).to be_truthy }
    context 'without absence feature' do
      before { Current.acp.update! features: [] }
      specify { expect(ability.can?(:create, Absence)).to be_falsey }
    end
  end

  context 'read-only' do
    let(:admin) { create(:admin, permission: Permission.create!(rights: {})) }

    specify { expect(ability.can?(:read, ActiveAdmin::Page)).to be_truthy }
    specify { expect(ability.can?(:pdf, Invoice)).to be_truthy }
    specify { expect(ability.can?(:read, ACP)).to be_falsey }
    specify { expect(ability.can?(:manage, Admin)).to be_falsey }
    specify { expect(ability.can?(:destroy, admin)).to be_falsey }
    specify { expect(ability.can?(:update, admin)).to be_truthy }
    specify { expect(ability.can?(:read, ActiveAdmin::Comment)).to be_truthy }
    specify { expect(ability.can?(:create, ActiveAdmin::Comment)).to be_truthy }
    specify { expect(ability.can?(:manage, create(:comment))).to be_falsey }
    specify { expect(ability.can?(:manage, create(:comment, author: admin))).to be_truthy }
  end

  context 'with member write permission' do
    let(:admin) { create(:admin, permission: Permission.create!(rights: { member: :write })) }

    specify { expect(ability.can?(:create, Member)).to be_truthy }
    specify { expect(ability.can?(:update, Member)).to be_truthy }

    specify { expect(ability.can?(:become, Member)).to be_truthy }
    specify { expect(ability.can?(:validate, Member.new(state: 'pending'))).to be_truthy }
  end

  context 'with membership write permission' do
    let(:admin) { create(:admin, permission: Permission.create!(rights: { membership: :write })) }

    specify { expect(ability.can?(:create, Membership)).to be_truthy }
    specify { expect(ability.can?(:update, Membership)).to be_truthy }
    specify { expect(ability.can?(:update, Basket)).to be_truthy }

    specify { expect(ability.can?(:renew_all, Membership)).to be_truthy }
    specify { expect(ability.can?(:open_renewal_all, Membership)).to be_truthy }
    specify { expect(ability.can?(:open_renewal, Membership)).to be_truthy }
    specify { expect(ability.can?(:enable_renewal, Membership)).to be_truthy }
    specify { expect(ability.can?(:renew, Membership)).to be_truthy }
    specify { expect(ability.can?(:cancel, Membership)).to be_truthy }
  end

  context 'with billing write permission' do
    let(:admin) { create(:admin, permission: Permission.create!(rights: { billing: :write })) }

    specify { expect(ability.can?(:create, Invoice)).to be_truthy }
    specify { expect(ability.can?(:update, Invoice)).to be_truthy }
    specify { expect(ability.can?(:create, Payment)).to be_truthy }
    specify { expect(ability.can?(:update, Payment)).to be_truthy }

    specify { expect(ability.can?(:force_recurring_billing, Member)).to be_truthy }
    specify { expect(ability.can?(:send_email, Invoice)).to be_truthy }
    specify { expect(ability.can?(:cancel, Invoice)).to be_truthy }
    specify { expect(ability.can?(:import, Payment)).to be_truthy }
  end

  context 'with billing group_buying permission' do
    before { Current.acp.update! features: [:group_buying] }
    let(:admin) { create(:admin, permission: Permission.create!(rights: { group_buying: :write })) }

    specify { expect(ability.can?(:create, GroupBuying::Delivery)).to be_truthy }
    specify { expect(ability.can?(:update, GroupBuying::Delivery)).to be_truthy }
    specify { expect(ability.can?(:create, GroupBuying::Order)).to be_truthy }
    specify { expect(ability.can?(:update, GroupBuying::Order)).to be_truthy }
    specify { expect(ability.can?(:create, GroupBuying::Product)).to be_truthy }
    specify { expect(ability.can?(:update, GroupBuying::Product)).to be_truthy }
    specify { expect(ability.can?(:create, GroupBuying::Producer)).to be_truthy }
    specify { expect(ability.can?(:update, GroupBuying::Producer)).to be_truthy }

    specify { expect(ability.can?(:cancel, GroupBuying::Order)).to be_truthy }
  end

  context 'with billing shop permission' do
    before { Current.acp.update! features: [:shop] }
    let(:admin) { create(:admin, permission: Permission.create!(rights: { shop: :write })) }

    specify { expect(ability.can?(:create, Shop::Order)).to be_truthy }
    specify { expect(ability.can?(:update, Shop::Order)).to be_truthy }
    specify { expect(ability.can?(:create, Shop::Product)).to be_truthy }
    specify { expect(ability.can?(:update, Shop::Product)).to be_truthy }
    specify { expect(ability.can?(:create, Shop::Producer)).to be_truthy }
    specify { expect(ability.can?(:update, Shop::Producer)).to be_truthy }
    specify { expect(ability.can?(:create, Shop::Tag)).to be_truthy }
    specify { expect(ability.can?(:update, Shop::Tag)).to be_truthy }

    specify { expect(ability.can?(:invoice, Shop::Order)).to be_truthy }
    specify { expect(ability.can?(:cancel, Shop::Order)).to be_truthy }
  end
end
