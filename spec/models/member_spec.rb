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
    describe 'support_member' do
      let(:member) { create(:member, :active) }
      it 'cannot become support member with current_membership' do
        member.update(support_member: true)
        expect(member.errors[:support_member]).to be_present
      end
    end

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

  describe '#waiting=' do
    let(:member) { create(:member, :waiting) }

    it 'sets waiting_started_at when "1"' do
      member = Member.create!(
        first_name: 'John',
        last_name: 'Doe',
        billing_interval: 'annual',
        support_member: false,
        waiting: '1',
      )
      expect(member.waiting_started_at).to be_present
    end

    it 'sets waiting_started_at when "0"' do
      expect { member.update!(waiting: '0') }
        .to change(member, :waiting_started_at).to(nil)
    end

    it 'creates a memberships alongs' do
      expect { member.update!(waiting: '0') }
        .to change(Membership, :count).by(1)
    end
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

  describe '#status' do
    %i[pending waiting trial active support inactive].each do |status|
      context "when #{status}" do
        let(:member) { create(:member, status) }
        specify { expect(member).to be_valid }
        specify { expect(member.status).to eq status }
        specify { expect(described_class.send(status)).to eq [member] }
      end
    end
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

    it 'sets status to waiting' do
      member.validate!(admin)
      expect(member.status).to eq :waiting
    end
  end

  describe '#name' do
    subject { Member.new(first_name: 'John', last_name: 'Doe').name }
    it { is_expected.to eq 'John Doe' }
  end

  describe '#emails= / #emails' do
    subject { Member.new(emails: 'john@doe.com, foo@bar.com').emails }
    it { is_expected.to eq 'john@doe.com, foo@bar.com' }
  end

  describe '#phones= / #phones' do
    subject { Member.new(phones: '1234, 4567').phones }
    it { is_expected.to eq '1234, 4567' }
  end

  describe '#absent?' do
    let(:member) { create(:member) }
    before do
      create(:absence,
        member: member,
        started_on: Time.zone.today,
        ended_on: 2.days.from_now
      )
    end

    specify { expect(member.absent?(Date.tomorrow)).to eq true }
  end
end
