require 'rails_helper'

describe RecurringBilling do
  before {
    travel_to(Date.new(Current.fy_year, 1, 15)) {
      create_deliveries(40)
    }
    Current.acp.update!(
      trial_basket_count: 0,
      billing_year_divisions: [1, 2, 3, 4, 12],
      fiscal_year_start_month: 1,
      recurring_billing_wday: 1) # Monday
  }
  after { travel_back }

  def create_invoice(member)
    member.reload
    RecurringBilling.invoice(member)
  end

  it 'does not create an invoice for inactive member (non-support)' do
    member = create(:member, :inactive)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'does not create an invoice for member with future membership' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      Current.acp.update!(trial_basket_count: 0)
      member = create(:member, billing_year_division: 12)
      create(:membership, member: member, started_on: 1.month.from_now)

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end
  end

  it 'creates an invoice for not already billed support member' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      member = create(:member, :support_annual_fee)
      invoice = create_invoice(member)

      expect(invoice.object).to be_nil
      expect(invoice.object_type).to eq 'AnnualFee'
      expect(invoice.annual_fee).to be_present
      expect(invoice.memberships_amount).to be_nil
      expect(invoice.amount).to eq invoice.annual_fee
      expect(invoice.pdf_file).to be_attached
    end
  end

  it 'does not create an invoice for already billed support member' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      member = create(:member, :support_annual_fee)
      create(:invoice, :annual_fee, member: member)

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end
  end

  it 'creates an invoice for trial membership when forced' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      Current.acp.update!(trial_basket_count: 4)
      member = create(:member)

      membership = create(:membership, member: member,
        started_on: 1.week.ago)

      expect(membership.trial?).to eq true

      expect { create_invoice(member) }.to change(Invoice, :count).by(1)
    end
  end

  it 'does not bill annual fee for canceled trial membership' do
    Current.acp.update!(
      billing_year_divisions: [12],
      trial_basket_count: 4)
    member = create(:member, :inactive, billing_year_division: 12)

    travel_to(Date.new(Current.fy_year, 8, 15))
    membership = create(:membership, member: member,
      started_on: 4.weeks.ago,
      ended_on: 1.day.ago)

    expect(membership.baskets_count).to eq 4

    invoice = create_invoice(member)

    expect(invoice.object).to eq membership
    expect(invoice.annual_fee).to be_nil
    expect(invoice.memberships_amount).to eq membership.price
    expect(invoice.pdf_file).to be_attached
  end

  it 'does not bill annual fee when member annual_fee is nil' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      member = create(:member, :support_annual_fee)
      member.update_column(:annual_fee, nil)

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end
  end

  it 'does not bill annual fee when member annual_fee is zero' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      member = create(:member, :support_annual_fee)
      member.update_column(:annual_fee, 0)

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end
  end

  it 'creates an invoice for already billed support member (last year)' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      member = create(:member, :support_annual_fee)
      create(:invoice, :annual_fee, member: member, date: 1.year.ago)
      invoice = create_invoice(member)

      expect(invoice.object).to be_nil
      expect(invoice.annual_fee).to be_present
      expect(invoice.memberships_amount).to be_nil
      expect(invoice.amount).to eq invoice.annual_fee
      expect(invoice.pdf_file).to be_attached
    end
  end

  context 'when billed yearly' do
    let(:member) { create(:member, :active, billing_year_division: 1) }
    let(:membership) { member.current_membership }

    specify 'when not already billed' do
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq 1200
      expect(invoice.memberships_amount_description).to eq 'Facturation annuelle'
      expect(invoice.memberships_amount).to eq membership.price
      expect(invoice.pdf_file).to be_attached
    end

    specify 'skip annual_fee when member one is set to 0' do
      member.update!(annual_fee: 0)

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
    end

    specify 'when not already billed with complements and many baskets' do
      create(:basket_complement, id: 1, price: 3.4, delivery_ids: Delivery.pluck(:id))
      create(:basket_complement, id: 2, price: 5.6, delivery_ids: Delivery.pluck(:id))

      travel_to(Current.fy_range.min) {
        membership.update!(
          basket_quantity: 2,
          basket_price: 32,
          depot_price: 3,
          memberships_basket_complements_attributes: {
            '0' => { basket_complement_id: 1, price: '', quantity: 1 },
            '1' => { basket_complement_id: 2, price: '', quantity: 2 }
          })
      }
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount)
        .to eq 40 * 2 * 32 + 40 * 2 * 3 + 40 * 3.4 + 40 * 2 * 5.6
      expect(invoice.memberships_amount_description).to eq 'Facturation annuelle'
      expect(invoice.memberships_amount).to eq membership.price
      expect(invoice.pdf_file).to be_attached
    end

    specify 'when salary basket & support member' do
      travel_to(Date.new(Current.fy_year, 1, 15)) do
        member = create(:member, :support_annual_fee, salary_basket: true)
        invoice = create_invoice(member)

        expect(invoice.object).to be_nil
        expect(invoice.annual_fee).to be_present
        expect(invoice.memberships_amount).to be_nil
        expect(invoice.pdf_file).to be_attached
      end
    end

    specify 'when already billed' do
      travel_to(Date.new(Current.fy_year, 1, 14)) { create_invoice(member) }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when membership did not started yet' do
      travel_to(Date.new(Current.fy_year, 1, 15)) do
        membership.update_column(:started_on, Date.tomorrow)

        expect { create_invoice(member) }.to change(Invoice, :count).by(1)
      end
    end

    specify 'when already billed, but with a membership change' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2, 15)) {
        membership.update!(depot_price: 2)
      }
      travel_to(Date.new(Current.fy_year, 1, 15))

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.object.baskets_count).to eq 40
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq 1200
      expect(invoice.memberships_amount_description).to be_present
      expect(invoice.memberships_amount).to eq 34 * 2
    end
  end

  context 'when billed quarterly' do
    let(:member) { create(:member, :active, billing_year_division: 4) }
    let(:membership) { member.current_membership }

    specify 'when quarter #1' do
      travel_to(Date.new(Current.fy_year, 1))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq membership.price
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #1'
    end

    specify 'when quarter #1 (already billed)' do
      travel_to(Date.new(2019, 1, 14)) {
        create_invoice(member)
      }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #2' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #2'
    end

    specify 'when quarter #2 (already billed)' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 6)) {
        expect { create_invoice(member) }.not_to change(Invoice, :count)
      }
    end

    specify 'when quarter #2 (already billed but canceled)' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5))
      create_invoice(member).cancel!
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #2'
    end

    specify 'when quarter #3' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 8))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 2.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #3'
    end

    specify 'when quarter #3 (with overpaid on previous invoices)' do
      @first_invoice = travel_to(Date.new(Current.fy_year, 1)) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 5)) {
        @second_invoice = create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 8))

      memberships_amount = membership.price / 4.0
      annual_fee = 30

      create(:payment, member: member, amount: memberships_amount + annual_fee + 15)
      create(:payment, member: member, amount: memberships_amount + 50)

      expect(@first_invoice.reload.overpaid).to be_zero
      expect(@second_invoice.reload.overpaid).to eq(65)
      invoice = create_invoice(member)

      expect(invoice.paid_memberships_amount).to eq membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #3'

      invoice.reload
      expect(@first_invoice.reload.overpaid).to be_zero
      expect(@second_invoice.reload.overpaid).to be_zero
      expect(invoice.missing_amount).to eq(invoice.amount - 65)
    end

    specify 'when quarter #3 (already billed)' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 7).end_of_month) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 8))

      expect(RecurringBilling.new(member.reload)).not_to be_billable
      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #3 (already billed), but with a membership change' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 7).end_of_month) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 8))
      membership.update!(depot_price: 2)

      expect(RecurringBilling.new(member.reload)).not_to be_billable
      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #4' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 11))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price * 3 / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price * 3 / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #4'
    end

    specify 'when quarter #4 (already billed)' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 10).end_of_month) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 11)) {
        expect(RecurringBilling.new(member.reload)).not_to be_billable
        expect { create_invoice(member) }.not_to change(Invoice, :count)
      }
    end

    specify 'when quarter #4 (already billed), but with a membership change' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 10).end_of_month) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 11)) {
        membership.baskets.last.update!(depot_price: 2)
        invoice = create_invoice(member)

        expect(invoice.object).to eq membership
        expect(invoice.annual_fee).to be_nil
        expect(invoice.paid_memberships_amount).to eq 1200
        expect(invoice.remaining_memberships_amount).to eq 1 * 2
        expect(invoice.memberships_amount).to eq 1 * 2
        expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #4'
      }
    end
  end

  context 'when billed mensualy' do
    before { Current.acp.update!(billing_year_divisions: [12]) }
    let(:member) { create(:member, :active, billing_year_division: 12) }
    let(:membership) { member.current_membership }

    specify 'when month #1' do
      travel_to(Date.new(Current.fy_year, 1))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq membership.price
      expect(invoice.memberships_amount).to eq membership.price / 12.0
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #1'
    end

    specify 'when month #3' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 3))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq (membership.price / 12.0) * 2
      expect(invoice.remaining_memberships_amount).to eq membership.price - (membership.price / 12.0) * 2
      expect(invoice.memberships_amount).to eq membership.price / 12.0
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #3'
    end

    specify 'when month #3 but membership ends at the end the month' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 3, 15))

      old_price = membership.price
      membership.update!(ended_on: Time.current.end_of_month)
      new_price = membership.price.to_f

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq((old_price / 12.0) * 2)
      expect(invoice.remaining_memberships_amount).to eq new_price - (old_price / 12.0) * 2
      expect(invoice.memberships_amount).to eq new_price - (old_price / 12.0) * 2
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #3'
    end

    specify 'when month #3 but membership ends in 3 months' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 3, 15))

      old_price = membership.price
      membership.update!(ended_on: 3.months.from_now.end_of_month)
      new_price = membership.price.to_f

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq((old_price / 12.0) * 2)
      expect(invoice.remaining_memberships_amount).to eq new_price - (old_price / 12.0) * 2
      expect(invoice.memberships_amount).to eq (new_price - (old_price / 12.0) * 2.0) / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #3'
    end

    specify 'when month #12' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 12, 15))

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq((membership.price / 12.0) * 2)
      expect(invoice.remaining_memberships_amount).to eq membership.price - (membership.price / 12.0) * 2
      expect(invoice.memberships_amount).to eq invoice.remaining_memberships_amount
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #12'
    end

    specify 'when month #3 but membership ended last month' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 3, 15))

      membership.update!(ended_on: 1.month.ago)

      expect(RecurringBilling.new(member.reload)).not_to be_billable
      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end
  end

  describe '#next_date' do
    specify 'pending member' do
      member = create(:member, :pending)
      expect(RecurringBilling.new(member).next_date).to be_nil
    end

    specify 'waiting member' do
      member = create(:member, :waiting)
      expect(RecurringBilling.new(member).next_date).to be_nil
    end

    specify 'inactive member' do
      member = create(:member, :inactive)
      expect(RecurringBilling.new(member).next_date).to be_nil
    end

    specify 'support_annual_fee member' do
      member = create(:member, :support_annual_fee)
      travel_to '2021-01-01' do # Friday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-04') # Monday
      end
      travel_to '2021-01-04' do # Monday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-04') # Monday
      end
    end

    specify 'support_annual_fee member already invoiced' do
      member = create(:member, :support_annual_fee)
      travel_to '2021-01-01' do # Friday
        create(:invoice, :annual_fee, member: member)
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2022-01-03') # Monday
      end
    end

    specify 'support_annual_fee member' do
      member = create(:member, state: 'support', desired_acp_shares_number: 2)
      travel_to '2021-01-01' do # Friday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-04') # Monday
      end
      travel_to '2021-01-04' do # Monday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-04') # Monday
      end
    end

    specify 'support_annual_fee member already invoiced' do
      Current.acp.update!(annual_fee: nil, share_price: 100)
      member = create(:member, :support_acp_share)
      travel_to '2021-01-01' do # Friday
        expect(RecurringBilling.new(member.reload).next_date).to be_nil
      end
    end


    specify 'membership beginning of the year, wait after first delivery' do
      create(:delivery, date: '2021-01-05') # Tuesday
      member = travel_to '2021-01-01' do # Friday
        create(:member, :active)
      end
      travel_to '2021-01-01' do # Friday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-11') # Monday
      end
      travel_to '2021-01-11' do # Monday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-11') # Monday
      end
      travel_to '2021-01-12' do # Tuesday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-18') # Monday
      end
    end

    specify 'membership beginning of the year, with ACP.billing_starts_after_first_delivery to false' do
      Current.acp.update!(billing_starts_after_first_delivery: false)
      create(:delivery, date: '2021-01-12') # Tuesday
      member = travel_to '2021-01-01' do # Friday
        create(:member, :active)
      end
      travel_to '2021-01-01' do # Friday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-04') # Monday
      end
      travel_to '2021-01-11' do # Monday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-11') # Monday
      end
      travel_to '2021-01-12' do # Tuesday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-01-18') # Monday
      end
    end

    specify 'membership just before end of year' do
      member = travel_to '2021-01-01' do # Friday
        create(:member, :active)
      end
      travel_to '2021-12-28' do # Tuesday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-12-28') # Tuesday
      end
    end

    specify 'membership already invoiced (billing_year_division 1)' do
      member = travel_to '2021-01-01' do # Friday
        create(:member, :active, billing_year_division: 1)
      end
      travel_to '2021-05-03' do # Monday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-05-03') # Monday
        create(:invoice, :membership,
          member: member,
          object: member.current_membership)
        expect(RecurringBilling.new(member.reload).next_date).to be_nil
      end
      travel_to '2021-12-01' do
        expect(RecurringBilling.new(member.reload).next_date).to be_nil
      end
    end

    specify 'membership already invoiced (billing_year_division 4)' do
      member = travel_to '2021-01-01' do # Friday
        create(:member, :active, billing_year_division: 4)
      end
      travel_to '2021-02-02' do # Tuesday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-02-08') # Monday
        create(:invoice, :membership,
          member: member,
          object: member.current_membership,
          membership_amount_fraction: 3)
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2021-04-05') # Monday
      end
      travel_to '2021-03-01' do # Monday
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2021-04-05') # Monday
      end
      travel_to '2021-05-01' do # Saturday
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2021-05-03') # Monday
      end
      travel_to '2021-12-28' do # Tuesday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-12-28') # Tuesday
      end
    end

    specify 'membership already invoiced (billing_year_division 12)' do
      member = travel_to '2021-01-01' do # Friday
        create(:member, :active, billing_year_division: 12)
      end
      travel_to '2021-02-02' do # Tuesday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-02-08') # Monday
        create(:invoice, :membership,
          member: member,
          object: member.current_membership,
          membership_amount_fraction: 10)
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2021-03-01') # Monday
      end
      travel_to '2021-03-01' do # Monday
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2021-03-01') # Monday
      end
      travel_to '2021-09-01' do # Wednesday
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2021-09-06') # Monday
      end
      travel_to '2021-12-28' do # Tuesday
        expect(RecurringBilling.new(member).next_date).to eq Date.parse('2021-12-28') # Tuesday
      end
    end

    specify 'future membership, current year' do
      member = create(:member, billing_year_division: 3)
      membership = travel_to '2021-01-01' do
        create(:membership,
          member: member,
          started_on: '2021-09-01') # Wednesday
      end
      expect(membership.deliveries.first.date).to eq Date.parse('2021-09-07') # Tuesday

      travel_to '2021-03-01' do # Monday
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2021-09-13') # Monday
      end
      travel_to '2021-11-01' do # Monday
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2021-11-01') # Monday
      end
    end

    specify 'future membership, next year' do
      member = create(:member, billing_year_division: 3)
      membership = travel_to '2022-01-01' do
        create(:membership, member: member) # Wednesday
      end
      expect(membership.deliveries.first.date).to eq Date.parse('2022-01-04') # Tuesday

      travel_to '2021-03-01' do # Monday
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2022-01-10') # Monday
      end
      travel_to '2021-11-01' do # Monday
        expect(RecurringBilling.new(member.reload).next_date).to eq Date.parse('2022-01-10') # Monday
      end
    end

    context 'with trial baskets' do
      before { Current.acp.update!(trial_basket_count: 4) }

      specify 'membership, four trial baskets' do
        membership = travel_to '2021-01-01' do
          create(:membership) # Monday
        end
        expect(membership.deliveries.first.date).to eq Date.parse('2021-01-05') # Tuesday
        expect(membership.baskets.not_trial.first.delivery.date).to eq Date.parse('2021-02-02') # Tuesday

        travel_to '2021-01-01' do # Monday
          expect(RecurringBilling.new(membership.member.reload).next_date).to eq Date.parse('2021-02-08') # Monday
        end
        travel_to '2021-02-09' do # Tuesday
          expect(RecurringBilling.new(membership.member.reload).next_date).to eq Date.parse('2021-02-15') # Monday
        end
        travel_to '2021-11-02' do # Tuesday
          expect(RecurringBilling.new(membership.member.reload).next_date).to eq Date.parse('2021-11-08') # Monday
        end
      end

      specify 'membership, three trial baskets' do
        membership = travel_to '2021-01-01' do
          create(:membership,
            started_on: '2021-09-20') # Monday
        end
        expect(membership.deliveries.count).to eq 3
        expect(membership.deliveries.first.date).to eq Date.parse('2021-09-21') # Tuesday
        expect(membership.deliveries.last.date).to eq Date.parse('2021-10-05') # Tuesday

        travel_to '2021-03-01' do # Monday
          expect(RecurringBilling.new(membership.member.reload).next_date).to eq Date.parse('2021-10-11') # Monday
        end
        travel_to '2021-09-21' do # Tuesday
          expect(RecurringBilling.new(membership.member.reload).next_date).to eq Date.parse('2021-10-11') # Monday
        end
        travel_to '2021-11-02' do # Tuesday
          expect(RecurringBilling.new(membership.member.reload).next_date).to eq Date.parse('2021-11-08') # Monday
        end
      end
    end
  end
end
