require 'rails_helper'

describe Member do
  fixtures :all

  describe 'validations' do
    describe 'support_member' do
      let(:member) { members(:john) }
      it 'cannot become support member with current_membership' do
        member.update(support_member: true)
        expect(member.errors[:support_member]).to be_present
      end
    end
  end

  describe '#membership=' do
    it 'creates a memberships alongs' do
      member = Member.create!(
        first_name: 'John',
        last_name: 'Doe',
        billing_interval: 'annual',
        support_member: false,
        membership: {
          basket_id: Basket.first.id,
          distribution_id: Distribution.first.id
        }
      )
      expect(member.current_membership).to be_present
    end
  end

  describe '#waiting_list=' do
    it 'sets waiting_from when "1"' do
      member = Member.create!(
        first_name: 'John',
        last_name: 'Doe',
        billing_interval: 'annual',
        support_member: false,
        waiting_list: '1',
      )
      expect(member.waiting_from).to be_present
    end

    it 'sets waiting_from when "0"' do
      member = members(:john)
      member.update(waiting_list: '1')
      expect{ member.update!(waiting_list: '0') }.to change(member, :waiting_from).to(nil)
    end
  end

  describe '#current_membership' do
    subject { members(:john).current_membership }
    it { is_expected.to eq memberships(:john_eveil) }
  end

  describe '.waiting_validation' do
    subject { Member.waiting_validation }
    it { is_expected.to eq [members(:waiting_validation)] }
  end

  describe '.waiting_list' do
    subject { Member.waiting_list }
    it { is_expected.to eq [members(:waiting_list)] }
  end

  describe '.active' do
    subject { Member.active }
    it { is_expected.to eq [members(:john), members(:bob)] }
  end

  describe '.support' do
    subject { Member.support }
    it { is_expected.to eq [members(:nick)] }
  end

  describe '.inactive' do
    subject { Member.inactive }
    it { is_expected.to eq [members(:inactive)] }
  end

  describe '#status' do
    subject { member.status }

    context 'when waiting_validation' do
      let(:member) { members(:waiting_validation) }
      it { is_expected.to eq :waiting_validation }
    end

    context 'when waiting_list' do
      let(:member) { members(:waiting_list) }
      it { is_expected.to eq :waiting_list }
    end

    context 'when active' do
      let(:member) { members(:john) }
      it { is_expected.to eq :active }
    end

    context 'when support' do
      let(:member) { members(:nick) }
      it { is_expected.to eq :support }
    end

    context 'when inactive' do
      let(:member) { members(:inactive) }
      it { is_expected.to eq :inactive }
    end
  end

  describe '#validate!' do
    let(:member) { members(:waiting_validation) }
    let(:admin) { Admin.first }

    it 'sets validated_at' do
      member.validate!(admin)
      expect(member.reload.validated_at).to be_present
    end

    it 'sets validator with admin' do
      member.validate!(admin)
      expect(member.reload.validator).to eq admin
    end

    it 'sets status to waiting_list' do
      member.validate!(admin)
      expect(member.reload.status).to eq :waiting_list
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
end
