require 'rails_helper'

describe 'GroupBuying::Order' do
  let(:member) { create(:member, id: 110128) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
    login(member)
  end

  it 'creates a new order' do
    current_acp.update!(features: ['group_buying'])
    create(:group_buying_delivery)
    create(:group_buying_product,
      name: 'Farine de Seigle 5kg',
      price: 3.15)

    visit '/'
    click_on 'Achats Groupés'

    fill_in 'Farine de Seigle 5kg', with: 2
    check "J'ai lu et j'accepte les conditions générales de vente"

    click_button 'Commander'

    expect(page).to have_content('Merci pour votre commande!')

    within('section.past_orders ul.billing') do
      expect(page).to have_content(/Commande #\d+ \(1 produit\)CHF 6.30/)
    end
  end

  it 'cannot access page without the group_buying feature enabled' do
    current_acp.update!(features: [])
    create(:group_buying_delivery)

    visit '/group_buying'

    expect(current_path).to eq('/billing')
    expect(page).not_to have_content('Achats Groupés')
  end

  it 'cannot access page without next delivery' do
    current_acp.update!(features: ['group_buying'])

    visit '/group_buying'

    expect(current_path).to eq('/billing')
    expect(page).not_to have_content('Achats Groupés')
  end
end
