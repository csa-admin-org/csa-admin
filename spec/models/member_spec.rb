require 'rails_helper'

describe Member do
  describe 'validations' do
    it 'requires address, city, zip on creation' do
      member = Member.new(
        address: nil,
        city: nil,
        zip: nil)
      expect(member).not_to have_valid(:address)
      expect(member).not_to have_valid(:city)
      expect(member).not_to have_valid(:zip)
    end

    it 'does not require address, city, zip when inactive' do
      member = create(:member, :inactive,
        address: nil,
        city: nil,
        zip: nil)
      expect(member).to be_valid
    end

    it 'does require address, city, zip on update' do
      member = create(:member)
      member.attributes = {
        address: nil,
        city: nil,
        zip: nil
      }
      expect(member).not_to have_valid(:zip)
      expect(member).not_to have_valid(:city)
      expect(member).not_to have_valid(:address)
    end

    it 'sets first ACP billing_year_divisions by default' do
      Current.acp.billing_year_divisions = [4, 12]
      member = create(:member, billing_year_division: nil)
      expect(member.billing_year_division).to eq 4
    end

    it 'only accepts ACP billing_year_divisions' do
      Current.acp.billing_year_divisions = [1, 12]
      member = Member.new(billing_year_division: 3)

      expect(member).not_to have_valid(:billing_year_division)
    end

    it 'validates email presence, but only on public creation' do
      member =  Member.new(emails: '')
      expect(member).to have_valid(:emails)

      member.public_create = true
      expect(member).not_to have_valid(:emails)
    end

    it 'validates email format' do
      member = Member.new(emails: 'doe.com, JANE@doe.com')
      expect(member).not_to have_valid(:emails)

      member = Member.new(emails: 'foo@bar.com;JANE@doe.com')
      expect(member).not_to have_valid(:emails)
    end

    it 'validates email uniqueness' do
      create(:member, emails: 'john@DOE.com, jane@doe.com')
      member = Member.new(emails: 'jen@doe.com, JANE@doe.com')

      expect(member).not_to have_valid(:emails)
    end

    it 'validates email uniqueness even when emails includes other ones' do
      create(:member, emails: 'super-john@DOE.com, mega-jane@doe.com')
      expect(Member.new(emails: 'john@DOE.com')).to have_valid(:emails)
      expect(Member.new(emails: 'JANE@doe.com')).to have_valid(:emails)
    end

    it 'validates annual_fee to be greater or equal to zero' do
      expect(Member.new(annual_fee: nil)).to have_valid(:annual_fee)
      expect(Member.new(annual_fee: 0)).to have_valid(:annual_fee)
      expect(Member.new(annual_fee: 1)).to have_valid(:annual_fee)
      expect(Member.new(annual_fee: -1)).not_to have_valid(:annual_fee)
    end
  end

  it 'strips whitespaces from emails' do
    member = Member.new(emails: ' foo@gmail.com ')

    expect(member.emails_array).to eq ['foo@gmail.com']
  end

  it 'initializes with annual_fee from ACP' do
    Current.acp.update!(annual_fee: 42)
    expect(Member.new.annual_fee).to eq 42
  end

  it 'updates waiting basket_size/depot' do
    member = create(:member, :waiting)
    new_basket_size = create(:basket_size)
    new_depot = create(:depot)

    member.update!(
      waiting_basket_size: new_basket_size,
      waiting_depot: new_depot)

    expect(member.state).to eq 'waiting'
    expect(member.waiting_started_at).to be_present
    expect(member.waiting_basket_size).to eq new_basket_size
    expect(member.waiting_depot).to eq new_depot
  end

  describe '#current_membership' do
    subject { create(:member, :active).current_membership }

    it { is_expected.to eq Membership.last }
  end

  describe '#validate!' do
    let(:admin) { create(:admin) }

    it 'sets state to waiting if waiting basket/depot' do
      member = create(:member, :pending,
        waiting_basket_size: create(:basket_size))

      expect { member.validate!(admin) }.to change(member, :state).to('waiting')
      expect(member.validated_at).to be_present
      expect(member.validator).to eq admin
    end

    it 'sets state to support if annual_fee is present' do
      member = create(:member, :pending,
        waiting_basket_size: nil,
        waiting_depot: nil,
        annual_fee: 30)

      expect { member.validate!(admin) }.to change(member, :state).to('support')
      expect(member.validated_at).to be_present
      expect(member.validator).to eq admin
    end

    it 'sets state to inactive if annual_fee is not present' do
      member = create(:member, :pending,
        waiting_basket_size: nil,
        waiting_depot: nil,
        annual_fee: nil)

      expect { member.validate!(admin) }.to change(member, :state).to('inactive')
      expect(member.validated_at).to be_present
      expect(member.validator).to eq admin
    end

    it 'raise if not pending' do
      member = create(:member, :support_annual_fee)
      expect { member.validate!(admin) }.to raise_error(RuntimeError)
    end
  end

  describe '#wait!' do
    it 'sets state to waiting and reset waiting_started_at' do
      Current.acp.update!(annual_fee: 30)
      member = create(:member, :support_annual_fee,
        waiting_started_at: 1.month.ago,
        annual_fee: 42)

      expect { member.wait! }.to change(member, :state).to('waiting')
      expect(member.waiting_started_at).to be > 1.minute.ago
      expect(member.annual_fee).to eq 42
    end

    it 'sets state to waiting and set default annual_fee' do
      Current.acp.update!(annual_fee: 30)
      member = create(:member, :inactive)

      expect { member.wait! }.to change(member, :state).to('waiting')
      expect(member.waiting_started_at).to be > 1.minute.ago
      expect(member.annual_fee).to eq 30
    end

    it 'raise if not support or inactive' do
      member = create(:member, :pending)
      expect { member.wait! }.to raise_error(RuntimeError)
    end
  end

  describe '#review_active_state!', freeze: '01-06-2018' do
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
    describe "two phones" do
      subject { Member.new(phones: '123456789, 987654321, ').phones }
      it { is_expected.to eq '+41123456789, +41987654321' }
    end
    describe "two phones with spaces and dots" do
      subject { Member.new(phones: '+41.12.345/67 89, 987/6543 21, ').phones }
      it { is_expected.to eq '+41123456789, +41987654321' }
    end
  end

  describe '#absent?' do
    it 'returns true for a given date during the absence window' do
      absence = create(:absence,
        started_on: 2.weeks.from_now,
        ended_on: 4.weeks.from_now)

      expect(absence.member.absent?(3.weeks.from_now)).to eq true
    end
  end

  describe '#activate!' do
    before { Current.acp.update!(notification_member_activated: '1') }

    it 'activates new active member and sent member-activated email' do
      member = create(:member, :inactive, activated_at: nil)
      membership = create(:membership,
        member: member,
        ended_on: 1.day.ago)
      membership.update_column(:ended_on, 1.day.from_now)
      member.reload

      expect { member.activate! }
        .to change(member, :state).from('inactive').to('active')
        .and change(member, :activated_at).from(nil)
        .and change { email_adapter.deliveries.size }.by(1)

      expect(email_adapter.deliveries.first).to match(
        hash_including(template: 'member-activated'))
    end

    it 'activates previously active member' do
      member = create(:member, :inactive, activated_at: 1.year.ago)
      membership = create(:membership,
        member: member,
        ended_on: 1.day.ago)
      membership.update_column(:ended_on, 1.day.from_now)
      member.reload

      expect { member.activate! }
        .not_to change(member, :activated_at)

      expect(email_adapter.deliveries).to be_empty
    end
  end

  describe '#deactivate!' do
    it 'sets state to inactive and clears waiting_started_at and annual_fee' do
      member = create(:member, :waiting, annual_fee: 42)

      expect { member.deactivate! }.to change(member, :state).to('inactive')
      expect(member.waiting_started_at).to be_nil
      expect(member.annual_fee).to be_nil
    end

    it 'sets state to inactive and clears annual_fee' do
      member = create(:member, :support_annual_fee, annual_fee: 42)

      expect { member.deactivate! }.to change(member, :state).to('inactive')
      expect(member.annual_fee).to be_nil
    end

    it 'sets state to inactive when membership ended' do
      member = create(:member, :active)
      member.membership.update_column(:ended_on, 1.day.ago)
      member.reload

      expect { member.deactivate! }.to change(member, :state).to('inactive')
      expect(member.annual_fee).to be_nil
    end

    it 'sets state to support when membership.renewal_annual_fee is present' do
      membership = create(:membership)
      member = membership.member
      membership.cancel!(renewal_annual_fee: '1')

      travel 1.year do
        member.reload
        expect { member.deactivate! }.to change(member, :state).to('support')
        expect(member.annual_fee).to eq 30
      end
    end

    it 'sets state to support when user still has acp_shares' do
      Current.acp.update!(share_price: 100, annual_fee: nil)
      member = create(:member, :active)
      member.membership.update_column(:ended_on, 1.day.ago)
      create(:invoice, member: member, acp_shares_number: 1, object_type: 'ACPShare')

      expect(member.acp_shares_number).to eq 1
      expect { member.deactivate! }.to change { member.reload.state }.to('support')
      expect(member.annual_fee).to be_nil
    end

    it 'raise if current membership' do
      member = create(:member, :active)

      expect { member.deactivate! }.to raise_error(RuntimeError)
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
        template: 'admin-member-new',
        template_data: hash_including(
          admin_name: admin1.name,
          member_name: member.name
        )))
    end

    it 'does not notify admin when not publicly created' do
      create(:admin, notifications: ['new_inscription'])
      create(:member, :waiting)

      expect(email_adapter.deliveries).to be_empty
    end
  end

  describe '#update_membership_if_salary_basket_changed' do
    it 'updates current year membership price' do
      membership = create(:membership)
      member = membership.member

      expect { member.reload.update!(salary_basket: true) }
        .to change { membership.reload.price }.to(0)
    end

    it 'updates future membership price' do
      membership = create(:membership, :next_year)
      member = membership.member

      expect { member.reload.update!(salary_basket: true) }
        .to change { membership.reload.price }.to(0)
    end
  end

  describe '#handle_annual_fee_change' do
    it 'changes inactive state to support when annual_fee is set' do
      member = create(:member, :inactive)
      expect { member.update!(annual_fee: 30) }
        .to change(member, :state).to('support')
    end

    it 'changes support state to inactive when annual_fee is cleared' do
      member = create(:member, :support_annual_fee)
      expect { member.update!(annual_fee: nil) }
        .to change(member, :state).to('inactive')
    end
  end
end
