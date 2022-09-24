require 'rails_helper'

describe Payment do
  specify 'store created_by via audit' do
    payment = create(:payment, :qr)
    expect(payment.created_by).to eq System.instance

    admin = create(:admin)
    Current.session = create(:session, admin: admin)
    payment = create(:payment)
    expect(payment.created_by).to eq admin
  end

  specify 'store updated_by' do
    payment = create(:payment)
    expect(payment.updated_by).to be_nil

    payment.update(amount: 1)
    expect(payment.updated_by).to eq System.instance

    admin = create(:admin)
    Current.session = create(:session, admin: admin)
    payment.update(amount: 2)
    expect(payment.updated_by).to eq admin
  end
end
