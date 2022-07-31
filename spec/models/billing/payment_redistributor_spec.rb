require 'rails_helper'

describe Billing::PaymentsRedistributor do
  describe '.redistribute!' do
    it 'splits payments amount on not canceled invoices' do
      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open,
        date: beginning_of_year,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice2 = create(:invoice, :open,
        date: beginning_of_year + 1.day,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #2',
        membership_amount_fraction: 2)
      invoice3 = create(:invoice, :canceled,
        date: beginning_of_year + 2.days,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 1)
      invoice3_bis = create(:invoice, :open,
        date: beginning_of_year + 3.days,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 1)

      create(:payment, member: member, invoice: invoice3, amount: 10)
      create(:payment, member: member, amount: 15)

      described_class.redistribute!(member.id)

      expect(invoice1.reload.paid_amount).to eq 10
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.paid_amount).to eq 10
      expect(invoice2.state).to eq 'closed'
      expect(invoice3.reload.paid_amount).to be_zero
      expect(invoice3.state).to eq 'canceled'
      expect(invoice3_bis.reload.paid_amount).to eq 5
      expect(invoice3_bis.state).to eq 'open'
    end

    it 'handles payments with invoice_id first' do
      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open,
        date: beginning_of_year,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice2 = create(:invoice, :open,
        date: beginning_of_year + 1.day,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #2',
        membership_amount_fraction: 2)
      invoice3 = create(:invoice, :open,
        date: beginning_of_year + 2.days,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 1)

      create(:payment, member: member, invoice: invoice1, amount: 10)
      create(:payment, member: member, invoice: invoice3, amount: 10)
      create(:payment, member: member, invoice: invoice3, amount: 3)
      create(:payment, member: member, amount: -2)

      described_class.redistribute!(member.id)

      expect(invoice1.reload.paid_amount).to eq 10
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.paid_amount).to eq 1
      expect(invoice2.state).to eq 'open'
      expect(invoice3.reload.paid_amount).to eq 10
      expect(invoice3.state).to eq 'closed'
    end


    it 'handles payments with invoice_id first, but remove money from the last invoice' do
      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open,
        date: beginning_of_year,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice2 = create(:invoice, :open,
        date: beginning_of_year + 1.day,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #2',
        membership_amount_fraction: 2)
      invoice3 = create(:invoice, :open,
        date: beginning_of_year + 2.days,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 1)

      create(:payment, member: member, invoice: invoice1, amount: 10)
      create(:payment, member: member, invoice: invoice3, amount: 10)
      create(:payment, member: member, invoice: invoice3, amount: 10)
      create(:payment, member: member, amount: -2)

      described_class.redistribute!(member.id)

      expect(invoice1.reload.paid_amount).to eq 10
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.paid_amount).to eq 10
      expect(invoice2.state).to eq 'closed'
      expect(invoice3.reload.paid_amount).to eq 8
      expect(invoice3.state).to eq 'open'
    end

    it 'prioritizes invoices with the same object types' do
      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open,
        date: beginning_of_year,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice2 = create(:invoice, :open, :manual,
        date: beginning_of_year + 1.day,
        member: member,
        items_attributes: { '0' => { description: 'Truc', amount: '5' } })
      invoice3 = create(:invoice, :open,
        date: beginning_of_year + 2.days,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #2',
        membership_amount_fraction: 1)

      create(:payment, member: member, invoice: invoice1, amount: 31)

      described_class.redistribute!(member.id)

      expect(invoice1.reload.paid_amount).to eq 10
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.paid_amount).to eq 1
      expect(invoice2.state).to eq 'open'
      expect(invoice3.reload.paid_amount).to eq 20
      expect(invoice3.state).to eq 'closed'
    end

    it 'prioritizes invoices with the same object types but only in the same fiscal year' do
      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open, :manual,
        date: beginning_of_year - 1.year,
        member: member,
        items_attributes: { '0' => { description: 'Truc', amount: '5' } })
      invoice2 = create(:invoice, :open,
        date: beginning_of_year + 1.day,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice3 = create(:invoice, :open, :manual,
        date: beginning_of_year + 2.day,
        member: member,
        items_attributes: { '0' => { description: 'Machin', amount: '10' } })

      create(:payment, member: member, invoice: invoice1, amount: 16)

      described_class.redistribute!(member.id)

      expect(invoice1.reload.paid_amount).to eq 5
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.paid_amount).to eq 10
      expect(invoice2.state).to eq 'closed'
      expect(invoice3.reload.paid_amount).to eq 1
      expect(invoice3.state).to eq 'open'
    end

    it 'handles payback invoice with negative amount' do
      Current.acp.update!(share_price: 2)

      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open,
        date: beginning_of_year,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice2 = create(:invoice, :open,
        date: beginning_of_year + 1.day,
        member: member,
        acp_shares_number: -2)
      invoice3 = create(:invoice, :open,
        date: beginning_of_year + 2.days,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 2)

      create(:payment, member: member, invoice: invoice1, amount: 10)

      described_class.redistribute!(member.id)

      expect(invoice1.reload.paid_amount).to eq 10
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.paid_amount).to be_zero
      expect(invoice2.state).to eq 'closed'
      expect(invoice3.reload.paid_amount).to eq 4
      expect(invoice3.state).to eq 'open'
    end

    it 'handles payback invoice with negative amount with direct negative payment' do
      Current.acp.update!(share_price: 2)

      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open,
        date: beginning_of_year,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice2 = create(:invoice, :open,
        date: beginning_of_year + 1.day,
        member: member,
        acp_shares_number: -2)
      invoice3 = create(:invoice, :open,
        date: beginning_of_year + 2.days,
        member: member,
        object: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 2)

      create(:payment, member: member, invoice: invoice1, amount: 10)
      create(:payment, member: member, invoice: invoice2, amount: -4)

      described_class.redistribute!(member.id)

      expect(invoice1.reload.paid_amount).to eq 10
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.paid_amount).to be_zero
      expect(invoice2.state).to eq 'closed'
      expect(invoice3.reload.paid_amount).to be_zero
      expect(invoice3.state).to eq 'open'
    end
  end
end
