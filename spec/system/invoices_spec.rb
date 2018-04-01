require 'rails_helper'

describe 'Invoices' do
  it 'creates an invoice for a rejected halfday participation' do
    member = create(:member, name: 'Jean Paul')
    create(:membership, id: 42, member: member)
    create(:halfday_participation, :rejected,
      id: 3,
      member: member,
      participants_count: 2)

    sign_in create(:admin, name: 'Sheriff')

    visit '/halfday_participations/3'
    click_link 'Facturer'

    fill_in 'Commentaire', with: 'A oublier de venir.'
    click_button 'Créer Facture'

    expect(page)
      .to have_content('Détails de Facture')
      .and have_content('Membre Jean Paul')
      .and have_content('Objet ½ Journée - Participation #3')
      .and have_content('Statut non-envoyée')
      .and have_content('Montant (CHF)  CHF 120.00')
      .and have_content('Commentaires (1)')
      .and have_content('Sheriff')
      .and have_content('A oublier de venir.')
  end
end
