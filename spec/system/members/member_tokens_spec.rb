require 'rails_helper'

describe 'members page' do
  before { Capybara.app_host = 'http://membres.ragedevert.test' }

  it 'recovers token from email' do
    member = create(:member, emails: 'thibaud@thibaud.gg, john@doe.com')

    visit '/wrong_token'
    expect(current_path).to eq '/token/recover'

    fill_in 'Votre email', with: 'thibaud@thibaud.gg'
    click_button 'Retrouver'

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      to: 'thibaud@thibaud.gg',
      template: 'member-login-fr',
      template_data: {
        action_url: "https://membres.ragedevert.ch/#{member.token}"
      }))

    expect(current_path).to eq '/token/recover'
    expect(page).to have_content 'Merci! Un email vient de vous être envoyé.'
  end

  it 'sends login help when email is not found' do
    visit '/token/recover'

    fill_in 'Votre email', with: 'unknown@member.com'
    click_button 'Retrouver'

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      to: 'unknown@member.com',
      template: 'member-login-help-fr',
      template_data: {}))

    expect(current_path).to eq '/token/recover'
    expect(page).to have_content 'Merci! Un email vient de vous être envoyé.'
  end
end
