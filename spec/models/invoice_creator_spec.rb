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
      expect(invoice.member_billing_interval).to eq member.billing_interval
      expect(invoice.memberships_amount).to be_nil
      expect(invoice.amount).to eq invoice.support_amount
      expect(invoice.pdf).to be_present
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
      expect(invoice.remaining_memberships_amount).to eq 1200
      expect(invoice.memberships_amount_description).to be_present
      expect(invoice.memberships_amount).to eq membership.price
      expect(invoice.pdf).to be_present
    end

    specify 'when salary basket & support member' do
      member.update!(salary_basket: true, support_member: true)

      expect(invoice.support_amount).to be_present
      expect(invoice.memberships_amount).to be_nil
      expect(invoice.pdf).to be_present
    end

    specify 'when already billed' do
      Timecop.travel(1.day.ago) { create_invoice }

      expect(invoice).to be_nil
    end

    specify 'when membership did not started yet' do
      Timecop.travel(1.day.from_now) { membership.touch(:started_on) }
      expect(invoice).to be_nil
    end

    specify 'when already billed, but with a membership change' do
      Timecop.travel(1.day.ago) { create_invoice }
      Timecop.travel(10.days.from_now) do
        membership.update!(distribution_id: create(:distribution, price: 2).id)
      end
      member.current_year_membership.reload

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
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #1'
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
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #2'
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
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #3'
    end

    specify 'when quarter #3 (with overbalance on previous invoices)' do
      @first_invoice = create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5)) {
        @second_invoice = create_invoice
      }
      Timecop.travel(Date.new(Time.zone.today.year, 8))

      memberships_amount = membership.price / 4.0
      support_amount = 30
      @first_invoice.update(manual_balance: memberships_amount + support_amount + 15)
      @second_invoice.update(manual_balance: memberships_amount + 50)

      expect(@first_invoice.overbalance).to eq(15)
      expect(@second_invoice.overbalance).to eq(50)

      expect(invoice.paid_memberships_amount).to eq membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #3'

      invoice.reload
      expect(@first_invoice.reload.overbalance).to be_zero
      expect(@second_invoice.reload.overbalance).to be_zero
      expect(invoice.manual_balance).to eq(65)
      expect(invoice.missing_amount).to eq(invoice.amount - 65)
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
      membership.update!(distribution_id: create(:distribution, price: 2).id)

      expect(invoice).to be_nil
    end

    specify 'when quarter #4' do
      create_invoice
      Timecop.travel(Date.new(Time.zone.today.year, 5)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 8)) { create_invoice }
      Timecop.travel(Date.new(Time.zone.today.year, 11))

      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price * 3 / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price * 3 / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #4'
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
      membership.update!(distribution_id: create(:distribution, price: 2).id)
      member.current_year_membership.reload

      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq 1200
      expect(invoice.remaining_memberships_amount).to eq 7 * 2
      expect(invoice.memberships_amount).to eq 7 * 2
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #4'
    end
  end
end
