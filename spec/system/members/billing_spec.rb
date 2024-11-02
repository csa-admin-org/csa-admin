# frozen_string_literal: true

require "rails_helper"

describe "Billing" do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = "http://membres.acme.test"
    login(member)
  end

  it "list open invoices" do
    create(:invoice, :annual_fee, id: 4242,
      member: member, date: "2018-2-1", annual_fee: 42)
    perform_enqueued_jobs

    visit "/"
    click_on "Facturation"

    expect(page).to have_content("Factures ouvertes")
    expect(page).to have_content("1 facture ouverte")
    expect(page).to have_content(
      [ "01.02.18", "Facture ouverte #4242 (Cotisation)", "CHF 42.00" ].join)
    expect(page).to have_content([ "Montant restant à payer", "CHF 42.00" ].join)
    expect(page).to have_content([ "Intervalle de paiement", "Annuel" ].join)
  end

  it "list invoices and payments history" do
    closed_invoice = create(:invoice, :annual_fee, id: 103,
      member: member, date: "2017-03-19", sent_at: nil)
    perform_enqueued_jobs
    closed_invoice.update_column(:state, "closed")
    invoice = create(:invoice, :activity_participation, id: 242,
      member: member, date: "2018-04-12", activity_price: 120)
    perform_enqueued_jobs
    create(:payment, invoice: invoice, member: member, date: "2018-5-1", amount: 162)

    visit "/billing"

    expect(page).to have_content("Historique")
    expect(page).to have_content(
      [ "01.05.18", "Paiement de la facture #242", "-CHF 162.00" ].join)
    expect(page).to have_content(
      [ "12.04.18", "Facture #242 (½ Journée)", "CHF 120.00" ].join)
    expect(page).to have_content(
      [ "19.03.17", "Facture #103 (Cotisation)", "CHF 30.00" ].join)

    expect(page).to have_content([ "Avoir", "CHF 12.00" ].join)
    expect(page).to have_content([ "Intervalle de paiement", "Annuel" ].join)
  end

  specify "show membership billing year division" do
    create(:membership, member: member, billing_year_division: 12)

    visit "/billing"

    expect(page).to have_content([ "Intervalle de paiement", "Mensuel" ].join)
  end
end
