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

  it 'initializes with support_price from ACP' do
    Current.acp.update!(support_price: 42)
    expect(Member.new.support_price).to eq 42
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
    let(:admin) { create(:admin) }

    it 'sets state to waiting if waiting basket/distribution' do
      member = create(:member, :pending,
        waiting_basket_size: create(:basket_size))

      expect { member.validate!(admin) }.to change(member, :state).to('waiting')
      expect(member.validated_at).to be_present
      expect(member.validator).to eq admin
    end

    it 'sets state to support if support_price is present' do
      member = create(:member, :pending,
        waiting_basket_size: nil,
        waiting_distribution: nil,
        support_price: 30)

      expect { member.validate!(admin) }.to change(member, :state).to('support')
      expect(member.validated_at).to be_present
      expect(member.validator).to eq admin
    end

    it 'sets state to inactive if support_price is not present' do
      member = create(:member, :pending,
        waiting_basket_size: nil,
        waiting_distribution: nil,
        support_price: nil)

      expect { member.validate!(admin) }.to change(member, :state).to('inactive')
      expect(member.validated_at).to be_present
      expect(member.validator).to eq admin
    end

    it 'raise if not pending' do
      member = create(:member, :support)
      expect { member.validate!(admin) }.to raise_error(RuntimeError)
    end
  end

  describe '#wait!' do
    it 'sets state to waiting and reset waiting_started_at' do
      Current.acp.update!(support_price: 30)
      member = create(:member, :support,
        waiting_started_at: 1.month.ago,
        support_price: 42)

      expect { member.wait! }.to change(member, :state).to('waiting')
      expect(member.waiting_started_at).to be > 1.minute.ago
      expect(member.support_price).to eq 42
    end

    it 'sets state to waiting and set default support_price' do
      Current.acp.update!(support_price: 30)
      member = create(:member, :inactive)

      expect { member.wait! }.to change(member, :state).to('waiting')
      expect(member.waiting_started_at).to be > 1.minute.ago
      expect(member.support_price).to eq 30
    end

    it 'raise if not support or inactive' do
      member = create(:member, :pending)
      expect { member.wait! }.to raise_error(RuntimeError)
    end
  end

  describe '#review_active_state!' do
    it 'activates new active member' do
      member = create(:member, :inactive)
      membership = create(:membership,
        member: member,
        ended_on: 1.day.ago)
      membership.update_column(:ended_on, 1.day.from_now)
      member.reload

      expect { member.review_active_state! }
        .to change(member, :state).from('inactive').to('active')
    end

    it 'deactivates old active member' do
      member = create(:member, :active)
      member.membership.update_column(:ended_on, 1.day.ago)
      member.reload

      expect { member.review_active_state! }
        .to change(member, :state).from('active').to('inactive')
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

  describe '#deactivate!' do
    it 'sets state to inactive and clears waiting_started_at and support_price' do
      member = create(:member, :waiting, support_price: 42)

      expect { member.deactivate! }.to change(member, :state).to('inactive')
      expect(member.waiting_started_at).to be_nil
      expect(member.support_price).to be_nil
    end

    it 'sets state to inactive and clears support_price' do
      member = create(:member, :support, support_price: 42)

      expect { member.deactivate! }.to change(member, :state).to('inactive')
      expect(member.support_price).to be_nil
    end

    it 'sets state to inactive when membership ended' do
      member = create(:member, :active)
      member.membership.update_column(:ended_on, 1.day.ago)
      member.reload

      expect { member.deactivate! }.to change(member, :state).to('inactive')
      expect(member.support_price).to be_nil
    end

    it 'raise if current membership' do
      member = create(:member, :active)

      expect { member.deactivate! }.to raise_error(RuntimeError)
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

  describe 'notify_new_inscription_to_admins' do
    it 'notifies admin with new_inscription notifications on when publicly created' do
      admin1 = create(:admin, notifications: ['new_inscription'])
      admin2 = create(:admin, notifications: [])

      member = create(:member, :waiting, public_create: true)

      expect(email_adapter.deliveries.size).to eq 1
      expect(email_adapter.deliveries.first).to match(hash_including(
        from: Current.acp.email_default_from,
        to: admin1.email,
        template: 'member-new-fr',
        template_data: {
          admin_name: admin1.name,
          member_name: member.name,
          action_url: "https://admin.ragedevert.ch/members/#{member.token}"
        }))
    end

    it 'does not notify admin when not publicly created' do
      create(:admin, notifications: ['new_inscription'])
      create(:member, :waiting)

      expect(email_adapter.deliveries).to be_empty
    end
  end

  describe '#handle_support_price_change' do
    it 'changes inactive state to support when support_price is set' do
      member = create(:member, :inactive)
      expect { member.update!(support_price: 30) }
        .to change(member, :state).to('support')
    end

    it 'changes support state to inactive when support_price is cleared' do
      member = create(:member, :support)
      expect { member.update!(support_price: nil) }
        .to change(member, :state).to('inactive')
    end
  end
end
