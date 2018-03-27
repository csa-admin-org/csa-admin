require 'rails_helper'

describe RecurringBilling do
  before { Timecop.travel(Date.new(Current.fy_year, 1, 15)) }
  after { Timecop.return }

  def create_invoice(member)
    RecurringBilling.invoice(member)
  end

  it 'does not create an invoice for inactive member (non-support)' do
    member = create(:member, :inactive)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'does not create an invoice for member with future membership' do
    Current.acp.update!(trial_basket_count: 0)
    member = create(:member)
    create(:membership, member: member, started_on: 1.day.from_now)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'creates an invoice for not already billed support member' do
    member = create(:member, :support)
    invoice = create_invoice(member)

    expect(invoice.object).to be_nil
    expect(invoice.support_amount).to be_present
    expect(invoice.memberships_amount).to be_nil
    expect(invoice.amount).to eq invoice.support_amount
    expect(invoice.pdf_file).to be_attached
  end

  it 'does not create an invoice for already billed support member' do
    member = create(:member, :support)
    create(:invoice, :support, member: member)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'does not create an invoice for trial membership' do
    Current.acp.update!(trial_basket_count: 4)
    member = create(:member)

    membership = create(:membership, member: member,
      started_on: 1.day.ago)

    expect(membership.trial?).to eq true

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'does not bill support for canceled trial membership' do
    Current.acp.update!(
      billing_year_divisions: [12],
      trial_basket_count: 4)
    member = create(:member, :inactive, billing_year_division: 12)

    Timecop.travel(Date.new(Current.fy_year, 8, 15))
    membership = create(:membership, member: member,
      started_on: 4.weeks.ago,
      ended_on: 1.day.ago)

    expect(membership.baskets_count).to eq 4

    invoice = create_invoice(member)

    expect(invoice.object).to eq membership
    expect(invoice.support_amount).to be_nil
    expect(invoice.memberships_amount).to eq membership.price
    expect(invoice.pdf_file).to be_attached
  end

  it 'does not bill support when support_price is zero' do
    member = create(:member, :support, support_price: 0)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'creates an invoice for already billed support member (last year)' do
    member = create(:member, :support)
    create(:invoice, :support, member: member, date: 1.year.ago)
    invoice = create_invoice(member)

    expect(invoice.object).to be_nil
    expect(invoice.support_amount).to be_present
    expect(invoice.memberships_amount).to be_nil
    expect(invoice.amount).to eq invoice.support_amount
    expect(invoice.pdf_file).to be_attached
  end

  context 'when billed yearly' do
    let(:member) { create(:member, :active, billing_year_division: 1) }
    let(:membership) { member.current_membership }

    specify 'when not already billed' do
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq 1200
      expect(invoice.memberships_amount_description).to eq 'Montant annuel'
      expect(invoice.memberships_amount).to eq membership.price
      expect(invoice.pdf_file).to be_attached
    end

    specify 'when not already billed with complements and many baskets' do
      create(:basket_complement, id: 1, price: 3.4, delivery_ids: Delivery.pluck(:id))
      create(:basket_complement, id: 2, price: 5.6, delivery_ids: Delivery.pluck(:id))

      Timecop.travel(Current.fy_range.min) {
        membership.update!(
          basket_quantity: 2,
          basket_price: 32,
          distribution_price: 3,
          memberships_basket_complements_attributes: {
            '0' => { basket_complement_id: 1, price: '', quantity: 1 },
            '1' => { basket_complement_id: 2, price: '', quantity: 2 }
          })
      }
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount)
        .to eq 40 * 2 * 32 + 40 * 2 * 3 + 40 * 3.4 + 40 * 2 * 5.6
      expect(invoice.memberships_amount_description).to eq 'Montant annuel'
      expect(invoice.memberships_amount).to eq membership.price
      expect(invoice.pdf_file).to be_attached
    end

    specify 'when salary basket & support member' do
      member = create(:member, :support, salary_basket: true)
      invoice = create_invoice(member)

      expect(invoice.object).to be_nil
      expect(invoice.support_amount).to be_present
      expect(invoice.memberships_amount).to be_nil
      expect(invoice.pdf_file).to be_attached
    end

    specify 'when already billed' do
      Timecop.travel(1.day.ago) { create_invoice(member) }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when membership did not started yet' do
      membership.update_column(:started_on, Date.tomorrow)

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when already billed, but with a membership change' do
      create_invoice(member)
      Timecop.travel(1.month.from_now) {
        membership.update!(distribution_price: 2)
      }
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq 1200
      expect(invoice.memberships_amount_description).to be_present
      expect(invoice.memberships_amount).to eq 38 * 2
    end
  end

  context 'when billed quarterly' do
    let(:member) { create(:member, :active, billing_year_division: 4) }
    let(:membership) { member.current_membership }

    specify 'when quarter #1' do
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq membership.price
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #1'
    end

    specify 'when quarter #1 (already billed)' do
      Timecop.travel(1.day.ago) { create_invoice(member) }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #2' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #2'
    end

    specify 'when quarter #2 (already billed)' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5)) {
        create_invoice(member)
      }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #2 (already billed but canceled)' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5))
      create_invoice(member).cancel!
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #2'
    end

    specify 'when quarter #3' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 8))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 2.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #3'
    end

    specify 'when quarter #3 (with overbalance on previous invoices)' do
      @first_invoice = create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5)) {
        @second_invoice = create_invoice(member)
      }
      Timecop.travel(Date.new(Current.fy_year, 8))

      memberships_amount = membership.price / 4.0
      support_amount = 30

      create(:payment, member: member, amount: memberships_amount + support_amount + 15)
      create(:payment, member: member, amount: memberships_amount + 50)

      expect(@first_invoice.reload.overbalance).to be_zero
      expect(@second_invoice.reload.overbalance).to eq(65)
      invoice = create_invoice(member)

      expect(invoice.paid_memberships_amount).to eq membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #3'

      invoice.reload
      expect(@first_invoice.reload.overbalance).to be_zero
      expect(@second_invoice.reload.overbalance).to be_zero
      expect(invoice.missing_amount).to eq(invoice.amount - 65)
    end

    specify 'when quarter #3 (already billed)' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 8))
      Timecop.travel(1.day.ago) { create_invoice(member) }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #3 (already billed), but with a membership change' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 8))
      Timecop.travel(1.day.ago) { create_invoice(member) }
      membership.update!(distribution_price: 2)

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #4' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 11))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price * 3 / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price * 3 / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #4'
    end

    specify 'when quarter #4 (already billed)' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 11))
      Timecop.travel(1.day.ago) { create_invoice(member) }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #4 (already billed), but with a membership change' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 11))
      Timecop.travel(1.day.ago) { create_invoice(member) }
      membership.update!(distribution_price: 2)
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq 1200
      expect(invoice.remaining_memberships_amount).to eq 8 * 2
      expect(invoice.memberships_amount).to eq 8 * 2
      expect(invoice.memberships_amount_description).to eq 'Montant trimestriel #4'
    end
  end

  context 'when billed mensualy' do
    before { Current.acp.update!(billing_year_divisions: [12]) }
    let(:member) { create(:member, :active, billing_year_division: 12) }
    let(:membership) { member.current_membership }

    specify 'when month #1' do
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq membership.price
      expect(invoice.memberships_amount).to eq membership.price / 12.0
      expect(invoice.memberships_amount_description).to eq 'Montant mensuel #1'
    end

    specify 'when month #3' do
      create_invoice(member)
      Timecop.travel(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      Timecop.travel(Date.new(Current.fy_year, 3))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.support_amount).to be_nil
      expect(invoice.paid_memberships_amount).to eq (membership.price / 12.0) * 2
      expect(invoice.remaining_memberships_amount).to eq membership.price - (membership.price / 12.0) * 2
      expect(invoice.memberships_amount).to eq membership.price / 12.0
      expect(invoice.memberships_amount_description).to eq 'Montant mensuel #3'
    end
  end
end
