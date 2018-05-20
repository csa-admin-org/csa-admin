require 'rails_helper'

describe Member do
  describe 'validations' do
    it 'does not require address, city, zip when inactive && newsletter' do
      member = create(:member, :inactive,
        newsletter: true,
        address: nil,
        city: nil,
        zip: nil
      )
      expect(member).to be_valid
    end

    it 'only accepts ACP billing_year_divisions' do
      Current.acp.billing_year_divisions = [1, 12]
      member = Member.new(billing_year_division: 3)

      expect(member).not_to have_valid(:billing_year_division)
    end
  end

  describe '#newsletter?' do
    it 'is true for these members' do
      [
        create(:member, :waiting),
        create(:member, :trial),
        create(:member, :active),
        create(:member, :support),
        create(:member, :inactive, newsletter: true)
      ].each { |member|
        expect(member.newsletter?).to eq true
      }
    end

    it 'is false for these members' do
      [
        create(:member, :pending),
        create(:member, :inactive),
        create(:member, :support, newsletter: false),
        create(:member, :active, newsletter: false)
      ].each { |member|
        expect(member.newsletter?).to eq false
      }
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

  it 'sets support_price from ACP if not set on creation' do
    Current.acp.update!(support_price: 42)
    member = create(:member, support_price: nil)

    expect(member.support_price).to eq 42
  end

  it 'updates waiting basket_size/distribution' do
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

  describe '#remove_from_waiting_list!' do
    it 'changes state from waiting to inactive' do
      member = create(:member, :waiting)

      expect { member.remove_from_waiting_list! }
        .to change { member.state }.from('waiting').to('inactive')
        .and change { member.waiting_started_at }.to(nil)
    end
  end

  describe '#put_back_to_waiting_list!' do
    it 'changes state from waiting to inactive' do
      member = create(:member, :inactive)

      expect { member.put_back_to_waiting_list! }
        .to change { member.state }.from('inactive').to('waiting')
        .and change { member.waiting_started_at }.from(nil)
    end

    it 'cleans support_member' do
      member = create(:member, :support)

      expect { member.put_back_to_waiting_list! }
        .to change { member.state }.from('inactive').to('waiting')
        .and change { member.support_member }.to(false)
    end
  end

  describe '#send_welcome_email' do
    it 'sents a welcome email when member becomes active' do
      member = create(:member, :active,
        emails: 'thibaud@thibaud.gg, john@doe.com',
        welcome_email_sent_at: nil)

      expect { member.send_welcome_email }
        .to change { email_adapter.deliveries.size }.by(1)
        .and change { member.welcome_email_sent_at }.from(nil)

      expect(email_adapter.deliveries.first).to match(hash_including(
        to: 'thibaud@thibaud.gg, john@doe.com',
        template: 'member-welcome-fr',
        template_data: {
          action_url: "https://membres.ragedevert.ch/#{member.token}"
        }))
    end

    it 'does nothing when user is not active' do
      member = create(:member, :pending,
        emails: 'thibaud@thibaud.gg, john@doe.com',
        welcome_email_sent_at: nil)
      expect { member.send_welcome_email }
        .not_to change { email_adapter.deliveries.size }
    end

    it 'does nothing when user has no emails' do
      member = create(:member, :pending, welcome_email_sent_at: nil)
      member.emails = ''
      expect { member.send_welcome_email }
        .not_to change { email_adapter.deliveries.size }
    end

    it 'does nothing when user has welcome_email_sent_at set' do
      member = create(:member, :active,
        emails: 'thibaud@thibaud.gg, john@doe.com',
        welcome_email_sent_at: Time.current)
      expect { member.send_welcome_email }
        .not_to change { email_adapter.deliveries.size }
    end
  end
end
