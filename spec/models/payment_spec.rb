require 'rails_helper'

describe Payment do
  describe '.update_invoices_balance!' do
    it 'splits payments amount on not canceled invoices' do
      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open,
        date: beginning_of_year,
        member: member,
        membership: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice2 = create(:invoice, :open,
        date: beginning_of_year + 1.day,
        member: member,
        membership: member.current_membership,
        memberships_amount_description: 'Montant #2',
        membership_amount_fraction: 2)
      invoice3 = create(:invoice, :canceled,
        date: beginning_of_year + 2.days,
        member: member,
        membership: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 1)
      invoice3_bis = create(:invoice, :open,
        date: beginning_of_year + 3.days,
        member: member,
        membership: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 1)

      create(:payment, member: member, invoice: invoice3, amount: 400)
      create(:payment, member: member, amount: 700)

      Payment.update_invoices_balance!(member.id)

      expect(invoice1.reload.balance).to eq 400
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.balance).to eq 400
      expect(invoice2.state).to eq 'closed'
      expect(invoice3.reload.balance).to be_zero
      expect(invoice3.state).to eq 'canceled'
      expect(invoice3_bis.reload.balance).to eq 300
      expect(invoice3_bis.state).to eq 'open'
    end

    it 'handles payments with invoice_id first' do
      member = create(:member, :active)
      beginning_of_year = Time.current.beginning_of_year
      invoice1 = create(:invoice, :open,
        date: beginning_of_year,
        member: member,
        membership: member.current_membership,
        memberships_amount_description: 'Montant #1',
        membership_amount_fraction: 3)
      invoice2 = create(:invoice, :open,
        date: beginning_of_year + 1.day,
        member: member,
        membership: member.current_membership,
        memberships_amount_description: 'Montant #2',
        membership_amount_fraction: 2)
      invoice3 = create(:invoice, :open,
        date: beginning_of_year + 2.days,
        member: member,
        membership: member.current_membership,
        memberships_amount_description: 'Montant #3',
        membership_amount_fraction: 1)

      create(:payment, member: member, invoice: invoice1, amount: 400)
      create(:payment, member: member, invoice: invoice3, amount: 400)
      create(:payment, member: member, invoice: invoice3, amount: 100)

      Payment.update_invoices_balance!(member.id)

      expect(invoice1.reload.balance).to eq 400
      expect(invoice1.state).to eq 'closed'
      expect(invoice2.reload.balance).to eq 100
      expect(invoice2.state).to eq 'open'
      expect(invoice3.reload.balance).to eq 400
      expect(invoice3.state).to eq 'closed'
    end
  end
end
