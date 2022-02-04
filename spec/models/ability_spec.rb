require 'rails_helper'

describe Ability do
  let(:ability) { Ability.new(admin) }

  context 'standard rights' do
    let(:admin) { create(:admin, rights: 'standard') }

    specify { expect(ability.can?(:manage, admin)).to be true }
    specify { expect(ability.can?(:read, Admin.new)).to be false }
    specify { expect(ability.can?(:read, MailTemplate)).to be true }
    specify { expect(ability.can?(:update, MailTemplate)).to be false }
    specify { expect(ability.can?(:manage, Member)).to be false }
    specify { expect(ability.can?(:create, Delivery)).to be false }
    specify { expect(ability.can?(:read, Member)).to be true }
    specify { expect(ability.can?(:destroy, Member)).to be false }
    specify { expect(ability.can?(:validate, Member)).to be false }
    specify { expect(ability.can?(:deactivate, Member.new(state: 'waiting'))).to be false }
    specify { expect(ability.can?(:wait, Member.new(state: 'inactive'))).to be false }
    specify { expect(ability.can?(:destroy, ActiveAdmin::Comment)).to be false }
    specify { expect(ability.can?(:create, ActiveAdmin::Comment)).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new(state: 'open'))).to be false }
    specify { expect(ability.can?(:destroy, Depot)).to be false }
    specify { expect(ability.can?(:destroy, BasketSize)).to be false }
    specify { expect(ability.can?(:destroy, BasketComplement)).to be false }
    specify { expect(ability.can?(:import, Payment)).to be false }

    specify { expect(ability.can?(:destroy, Activity)).to be true }
    specify 'activity with participation' do
      activity = create(:activity_participation).activity
      expect(ability.can?(:destroy, activity)).to be false
    end
  end

  context 'admin rights' do
    let(:admin) { create(:admin, rights: 'admin') }

    specify { expect(ability.can?(:manage, admin)).to be true }
    specify { expect(ability.can?(:read, Admin.new)).to be true }
    specify { expect(ability.can?(:read, MailTemplate)).to be true }
    specify { expect(ability.can?(:update, MailTemplate)).to be false }
    specify { expect(ability.can?(:create, Member)).to be true }
    specify { expect(ability.can?(:update, Member)).to be true }
    specify { expect(ability.can?(:destroy, Member)).to be true }
    specify { expect(ability.can?(:validate, Member)).to be true }
    specify { expect(ability.can?(:create, Delivery)).to be true }
    specify { expect(ability.can?(:update, Delivery)).to be true }
    specify { expect(ability.can?(:destroy, Delivery)).to be true }
    specify { expect(ability.can?(:deactivate, Member.new(state: 'waiting'))).to be true }
    specify { expect(ability.can?(:deactivate, Member.new(state: 'support'))).to be true }
    specify { expect(ability.can?(:wait, Member.new(state: 'inactive'))).to be true }
    specify { expect(ability.can?(:destroy, ActiveAdmin::Comment)).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new(state: 'processing'))).to be false }
    specify { expect(ability.can?(:destroy, Invoice.new(state: 'open'))).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new(state: 'open', sent_at: Time.current))).to be false }
    specify { expect(ability.can?(:destroy, Depot)).to be false }
    specify { expect(ability.can?(:destroy, BasketSize)).to be false }
    specify { expect(ability.can?(:destroy, BasketComplement)).to be false }
    specify { expect(ability.can?(:import, Payment)).to be true }

    context 'share price' do
      before { Current.acp.update!(share_price: 420) }

      specify { expect(ability.can?(:deactivate, Member.new(state: 'waiting'))).to be true }
      specify { expect(ability.can?(:deactivate, Member.new(state: 'support'))).to be false }
    end
  end

  context 'superadmin rights' do
    let(:admin) { create(:admin, rights: 'superadmin') }

    specify { expect(ability.can?(:manage, admin)).to be true }
    specify { expect(ability.can?(:manage, Admin.new)).to be true }
    specify { expect(ability.can?(:create, MailTemplate)).to be true }
    specify { expect(ability.can?(:create, Member)).to be true }
    specify { expect(ability.can?(:update, Member)).to be true }
    specify { expect(ability.can?(:destroy, Member)).to be true }
    specify { expect(ability.can?(:validate, Member)).to be true }
    specify { expect(ability.can?(:deactivate, Member.new(state: 'waiting'))).to be true }
    specify { expect(ability.can?(:wait, Member.new(state: 'inactive'))).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new(state: 'processing'))).to be false }
    specify { expect(ability.can?(:destroy, Invoice.new(state: 'open'))).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new(state: 'open', sent_at: Time.current))).to be false }
    specify { expect(ability.can?(:destroy, Depot)).to be true }
    specify { expect(ability.can?(:destroy, BasketSize)).to be true }
    specify { expect(ability.can?(:destroy, BasketComplement)).to be true }
    specify { expect(ability.can?(:import, Payment)).to be true }

    specify 'when used' do
      depot = create(:depot)
      basket_size = create(:basket_size)
      basket_complement = create(:basket_complement)
      create(:membership,
        depot: depot,
        basket_size: basket_size,
        subscribed_basket_complement_ids: [basket_complement.id])

      expect(ability.can?(:destroy, depot)).to be false
      expect(ability.can?(:destroy, basket_size)).to be false
      expect(ability.can?(:destroy, basket_complement)).to be false
    end
  end
end
