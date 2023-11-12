require 'rails_helper'

describe 'Info' do
  before { Capybara.app_host = 'http://membres.ragedevert.test' }

  specify 'show informations link' do
    Current.acp.update!(member_information_text: 'Some confidential infos')
    login(create(:member))

    visit '/'

    expect(page).to have_link('Informations')

    click_on 'Informations'

    expect(current_path).to eq('/info')
    expect(page).to have_content('Informations')
    expect(page).to have_content('Some confidential infos')
  end

  specify 'show informations with custom title' do
    Current.acp.update!(
      member_information_title: 'Archive',
      member_information_text: 'Some confidential archive infos')
    login(create(:member))

    visit '/'

    expect(page).to have_link('Archive')

    click_on 'Archive'

    expect(current_path).to eq('/info')
    expect(page).to have_content('Archive')
    expect(page).to have_content('Some confidential archive infos')
  end

  specify 'do not show informations when not set' do
    Current.acp.update!(member_information_text: nil)
    login(create(:member))

    visit '/'
    expect(page).not_to have_link('Informations')

    visit '/info'
    expect(current_path).not_to eq('/info')
  end

  specify 'do not show informations when not logged in' do
    Current.acp.update!(member_information_text: 'Some confidential infos')

    visit '/info'
    expect(current_path).to eq('/login')
  end
end
