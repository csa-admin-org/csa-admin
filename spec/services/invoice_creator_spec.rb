require 'rails_helper'

describe InvoiceCreator do
  let(:invoice) { create_invoice }
  before { Timecop.travel(Date.new(Time.zone.today.year, 2)) }
  after { Timecop.return }

  def create_invoice
    InvoiceCreator.new(member).create
  end

  context 'when inactive member (non-support)' do
    let(:member) { create(:member, :inactive) }

    specify { expect(invoice).to be_nil }
  end

  context 'when not already billed support member' do
    let(:member) { create(:member, :support) }

    specify do
      expect(invoice.support_amount).to be_present
      expect(invoice.memberships_amount).to be_nil
      expect(invoice.amount).to eq invoice.support_amount
    end

    pending 'sends new invoice email' do
      expect { invoice }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq invoice.member.emails_array
    end
  end

  context 'when already billed support member' do
    before { create(:invoice, :support, member: member) }
    let(:member) { create(:member, :support) }

    specify { expect(invoice).to be_nil }
  end

  context 'when already billed support member (last year)' do
    before { create(:invoice, :last_year, :support, member: member) }
    let(:member) { create(:member, :support) }

    specify { expect(invoice.support_amount).to be_present }
  end

  context 'when billed yearly' do
    let(:member) { create(:member, :active) }
    let(:membership) { member.current_membership }
    before { member.billing_interval = 'annual' }

    specify 'when not already billed' do
      expect(invoice.support_amount).to be_present
      expect(invoice.paid_memberships_amount).to eq 0
      expect(invoice.memberships_amount_description).to be_present
      expect(invoice.memberships_amount).to eq membership.price
      expect(invoice.memberships_amounts_data.first).to match(
        'id' => membership.id,
        'amount' => membership.price,
        'description' => String
      )
    end

    specify 'when salary basket & support member' do
      member.update(salary_basket: true, support_member: true)

      expect(invoice.support_amount).to be_present
      expect(invoice.memberships_amount).to be_nil
    end

    specify 'when already billed' do
      Timecop.travel(1.day.ago) { create_invoice }

      expect(invoice).to be_nil
    end

    specify 'when already billed, but with a membership change' do
      Timecop.travel(1.day.ago) { create_invoice }
      membership.update!(
        will_be_changed_at: 10.days.from_now.to_s,
        distribution_id: create(:distribution, basket_price: 2).id
      )
      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq 1200
      expect(invoice.memberships_amount_description).to be_present
      expect(invoice.memberships_amount).to eq 38 * 2
    end
  end

  context 'when billed quarterly' do
    before { member.billing_interval = 'quarterly' }
    let(:member) { create(:member, :active) }
    let(:membership) { member.current_membership }

    specify 'when quarter #1' do
      expect(invoice.support_amount).to be_present
      expect(invoice.paid_memberships_amount).to eq 0
      expect(invoice.remaining_memberships_amount).to eq membership.price
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description)
        .to eq 'Montant trimestriel #1'
      expect(invoice.memberships_amounts_data.first).to match(
        'id' => membership.id,
        'amount' => membership.price,
        'description' => String
      )
    end

    specify 'when quarter #1 (already billed)' do
      Timecop.travel(1.day.ago) { create_invoice }

      expect(invoice).to be_nil
    end

    specify 'when quarter #2' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5))

      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 4.0
      expect(invoice.remaining_memberships_amount)
        .to eq membership.price - membership.price / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description)
        .to eq 'Montant trimestriel #2'
    end

    specify 'when quarter #2 (already billed)' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5))
      Timecop.travel(1.day.ago) { create_invoice }

      expect(invoice).to be_nil
    end

    specify 'when quarter #3' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 8))

      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 2.0
      expect(invoice.remaining_memberships_amount)
        .to eq membership.price - membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description)
        .to eq 'Montant trimestriel #3'
    end

    specify 'when quarter #3 (already billed)' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 8))
      Timecop.travel(1.day.ago) { create_invoice }

      expect(invoice).to be_nil
    end

    specify 'when quarter #3 (already billed), but with a membership change' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 8))
      Timecop.travel(1.day.ago) { create_invoice }
      membership.update!(
        will_be_changed_at: 1.day.from_now.to_s,
        distribution_id: create(:distribution, basket_price: 2).id
      )

      expect(invoice).to be_nil
    end

    specify 'when quarter #4' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 8)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 11))

      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price * 3 / 4.0
      expect(invoice.remaining_memberships_amount)
        .to eq membership.price - membership.price * 3 / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description)
        .to eq 'Montant trimestriel #4'
    end

    specify 'when quarter #4 (already billed)' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 8)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 11))
      Timecop.travel(1.day.ago) { create_invoice }

      expect(invoice).to be_nil
    end

    specify 'when quarter #4 (already billed), but with a membership change' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 8)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 11))
      Timecop.travel(1.day.ago) { create_invoice }
      membership.update!(
        will_be_changed_at: 1.day.from_now.to_s,
        distribution_id: create(:distribution, basket_price: 2).id
      )

      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq 1200
      expect(invoice.remaining_memberships_amount).to eq 7 * 2
      expect(invoice.memberships_amount).to eq 7 * 2
      expect(invoice.memberships_amount_description)
        .to eq 'Montant trimestriel #4'
    end
  end
end
