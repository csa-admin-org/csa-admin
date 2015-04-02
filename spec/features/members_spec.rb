require 'rails_helper'

feature 'members page' do
  let!(:member) { create(:member, :active) }
  let!(:halfday_work) { create(:halfday_work, member: member) }

  before { Capybara.app_host = 'http://membres.example.com' }

  context 'existing member token' do
    before { visit "/#{member.token}" }
    scenario 'add new halfday work' do
      check 'halfday_work_period_am'
      check 'halfday_work_period_pm'
      fill_in 'halfday_work_participants_count', with: 3
      click_button 'Inscription'

      expect(page)
        .to have_content "#{I18n.l Date.today, format: :long}8:00 - 17:303"
    end

    scenario 'remove halfday work' do
      date = halfday_work.date
      date_text = I18n.l(date, format: :long)

      expect(page).to have_content date_text
      click_button 'Effacer', match: :first
      expect(page).not_to have_content date_text
    end
  end

  context 'wrong member token' do
    let(:email) { member.emails_array.first }

    scenario 'recover token from email' do
      visit '/wrong_token'
      expect(current_path).to eq '/token/recover'

      fill_in 'email', with: email
      click_button 'Retrouver'

      open_email(email)
      expect(current_email.body)
        .to include "membres.ragedevert.ch/#{member.token}"

      expect(current_path).to eq '/token/recover'
      expect(page).to have_content 'Merci'
    end
  end
end
