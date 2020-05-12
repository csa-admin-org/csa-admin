require 'rails_helper'

describe 'Account' do
  let(:member) {
    create(:member,
      name: 'Doe Jame and John',
      address: 'Nowhere 1',
      zip: '1234',
      city: 'Town',
      emails: 'john@doe.com, jame@doe.com',
      phones: '076 123 45 67, 079 765 43 21')
  }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
    login(member)
  end

  it 'shows current member data' do
    visit '/'

    click_on 'Doe Jame and John'

    expect(page).to have_content("Nom\nDoe Jame and John")
    expect(page).to have_content("Adresse\nNowhere 11234 Town")
    expect(page).to have_content("Email(s)\njohn@doe.com, jame@doe.com")
    expect(page).to have_content("Téléphone(s)\n076 123 45 67, 079 765 43 21")
  end

  it 'edits current member data' do
    visit '/'

    click_on 'Doe Jame and John'
    click_on 'Modifier les données du compte'

    fill_in 'Nom', with: 'Doe Jame & John'
    fill_in 'member_zip', with: '12345'
    fill_in 'member_city', with: 'Villar'

    click_button 'Soumettre'

    expect(page).to have_content("Nom\nDoe Jame & John")
    expect(page).to have_content("Adresse\nNowhere 112345 Villar")

    expect(member.audits.first).to have_attributes(
      session: member.last_session,
      audited_changes: {
        'zip' => ['1234', '12345'],
        'city' => ['Town', 'Villar'],
        'name' => ['Doe Jame and John', 'Doe Jame & John']
      })
  end
end
