require 'rails_helper'

describe 'Billing' do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
    login(member)
  end

  it 'list open invoices' do
    create(:invoice, :annual_fee, id: 4242,
      member: member, date: '2018-2-1', annual_fee: 42)

    visit '/'
    click_on 'Facturation'

    expect(page).to have_content('Factures ouvertes')
    expect(page).to have_content('1 facture ouverte')
    expect(page).to have_content(
      ['01.02.2018', 'Facture ouverte #4242 (Cotisation)', ' CHF 42.00'].join)
    expect(page).to have_content('Montant restant à payer: CHF 42.00')
    expect(page).to have_content('Intervalle de paiement: Trimestriel')
  end

  it 'list invoices and payments history' do
    member.update!(billing_year_division: 1)
    closed_invoice = create(:invoice, :annual_fee, id: 103,
      member: member, date: '2017-03-19', sent_at: nil)
    closed_invoice.update_column(:state, 'closed')
    inovice = create(:invoice, :activity_participation, id: 242,
      member: member, date: '2018-04-12', paid_missing_activity_participations_amount: 120)
    create(:payment, invoice: inovice, member: member, date: '2018-5-1', amount: 162)

    visit '/billing'

    expect(page).to have_content('Historique')
    expect(page).to have_content(
      ['01.05.2018', 'Paiement de la facture #242', '-CHF 162.00'].join)
    expect(page).to have_content(
      ['12.04.2018', 'Facture #242 (½ Journée)', ' CHF 120.00'].join)
    expect(page).to have_content(
      ['19.03.2017', 'Facture #103 (Cotisation)', ' CHF 30.00'].join)

    expect(page).to have_content('Avoir: CHF 12.00')
    expect(page).to have_content('Intervalle de paiement: Annuel')
  end
end
