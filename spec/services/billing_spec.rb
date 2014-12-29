require 'rails_helper'

describe Billing do
  fixtures :all

  describe '.all' do
    let(:billings) { described_class.all }

    it 'bills everything' do
      expect(billings.size).to eq 3
    end

    it 'bills billing_member' do
      billing = billings.first
      expect(billing.member_name).to eq members(:john).name
      expect(billing.price).to eq 159.75
      expect(billing.details).to include('/')
    end

    it 'bills inactive' do
      billing = billings.second
      expect(billing.member_name).to eq members(:inactive).name
      expect(billing.price).to eq 30.125
    end

    it 'bills support' do
      billing = billings.last
      expect(billing.member_name).to eq members(:nick).name
      expect(billing.price).to eq 30
    end
  end
end
