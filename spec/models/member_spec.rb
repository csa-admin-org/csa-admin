require 'rails_helper'

describe Member do
  describe '.gribouille_emails' do
    let!(:pending_member) { create(:member, :pending) }
    let!(:waiting_member) { create(:member, :waiting) }
    let!(:trial_member) { create(:member, :trial) }
    let!(:active_member) { create(:member, :active) }
    let!(:non_gribouille_member) { create(:member, :active, gribouille: false) }
    let!(:support_member) { create(:member, :support) }
    let!(:inactive_member) { create(:member, :inactive) }
    let!(:gribouille_member) { create(:member, :inactive, gribouille: true) }

    it 'returns all gribouille emails' do
      expect(Member.gribouille_emails).to match_array(
        waiting_member.emails_array + trial_member.emails_array +
        active_member.emails_array + support_member.emails_array +
        gribouille_member.emails_array
      )
    end
  end

  describe 'validations' do
    it 'does not require address, city, zip when inactive && gribouille' do
      member = create(:member, :inactive,
        gribouille: true,
        address: nil,
        city: nil,
        zip: nil
      )
      expect(member).to be_valid
    end
  end

  it 'sets state and waiting_started_at if basket_size/distribution present on creation' do
    member = create(:member,
      waiting_started_at: nil,
      waiting_basket_size: create(:basket_size),
      waiting_distribution: create(:distribution))

    expect(member.state).to eq 'waiting'
    expect(member.waiting_started_at).to be_present
  end

  it 'updates waiting basket_size/distribution on update' do
    member = create(:member, :waiting)
    new_basket_size = create(:basket_size)
    new_distribution = create(:distribution)

    member.update!(
      waiting_basket_size: new_basket_size,
      waiting_distribution: new_distribution)

    expect(member.state).to eq 'waiting'
    expect(member.waiting_started_at).to be_present
    expect(member.waiting_basket_size).to eq new_basket_size
    expect(member.waiting_distribution).to eq new_distribution
  end

  describe '#support_member=' do
    let(:member) { create(:member) }

    it 'sets billing_interval to annual' do
      member.billing_interval = 'quarterly'
      member.update(support_member: '1')
      expect(member.billing_interval).to eq 'annual'
    end
  end

  describe '#current_membership' do
    subject { create(:member, :active).current_membership }

    it { is_expected.to eq Membership.last }
  end

  describe '#validate!' do
    let(:member) { create(:member, :pending) }
    let(:admin) { create(:admin) }

    it 'sets validated_at' do
      member.validate!(admin)
      expect(member.validated_at).to be_present
    end

    it 'sets validator with admin' do
      member.validate!(admin)
      expect(member.validator).to eq admin
    end

    it 'sets state to waiting' do
      member.validate!(admin)
      expect(member.state).to eq 'waiting'
    end
  end

  describe '#emails= / #emails' do
    subject { Member.new(emails: 'john@doe.com, foo@bar.com').emails }
    it { is_expected.to eq 'john@doe.com, foo@bar.com' }
  end

  describe '#phones= / #phones' do
    subject { Member.new(phones: '123456789, 987654321').phones }
    it { is_expected.to eq '+41123456789, +41987654321' }
  end

  describe '#absent?' do
    let(:member) { create(:member) }
    before do
      create(:absence,
        member: member,
        started_on: Date.current,
        ended_on: 2.days.from_now
      )
    end

    specify { expect(member.absent?(Date.tomorrow)).to eq true }
  end
end
