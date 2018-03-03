require 'rails_helper'

describe 'Admin login page' do
  before { Capybara.app_host = 'http://admin.ragedevert.test' }

  it 'logins admin' do
    create(:admin,
      email: 'john@doe.com',
      password: 'SuperSecr3t',
      password_confirmation: 'SuperSecr3t')

    visit '/'
    expect(current_path).to eq '/login'

    fill_in 'Email', with: 'john@doe.com'
    fill_in 'Mot de passe', with: 'SuperSecr3t'
    click_button 'Se connecter'

    expect(current_path).to eq '/'
    expect(page).to have_content 'Tableau de bord'
    expect(page).to have_content 'Rage de Vert'
  end

  it 'does not login admin with wrong password' do
    create(:admin,
      email: 'john@doe.com',
      password: 'SuperSecr3t',
      password_confirmation: 'SuperSecr3t')

    visit '/login'
    fill_in 'Email', with: 'john@doe.com'
    fill_in 'Mot de passe', with: 'a_bad_one'
    click_button 'Se connecter'

    expect(current_path).to eq '/login'
    expect(page).to have_content 'Email ou mot de passe incorrect'
  end

  it 'logins admin in another ACP' do
    create(:acp,
      name: 'Lumière des Champs',
      host: 'lumiere-des-champs',
      tenant_name: 'lumieredeschamps')
    ACP.enter!('lumieredeschamps')
    Capybara.app_host = 'http://admin.lumiere-des-champs.test'

    create(:admin,
      email: 'john@doe.com',
      password: 'SuperSecr3t',
      password_confirmation: 'SuperSecr3t')

    visit '/'
    fill_in 'Email', with: 'john@doe.com'
    fill_in 'Mot de passe', with: 'SuperSecr3t'
    click_button 'Se connecter'

    expect(current_path).to eq '/'
    expect(page).to have_content 'Tableau de bord'
    expect(page).to have_content 'Lumière des Champs'
  end
end
