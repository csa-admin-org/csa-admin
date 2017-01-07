require 'rails_helper'

feature 'members page' do
  let!(:member) { create(:member, :active) }
  let!(:halfday_participation) { create(:halfday_participation, member: member) }

  before { Capybara.app_host = 'http://membres.example.com' }

  context 'existing member token' do
    let!(:halfday) { create(:halfday, date: 4.days.from_now) }
    before { visit "/#{member.token}" }

    scenario 'add new participation' do
      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      click_button 'Inscription'
      expect(page)
        .to have_content "#{I18n.l(halfday.date, format: :medium).capitalize}, #{halfday.period}"
      expect(page).not_to have_content "oui (#{member.phones_array.first})"
    end

    scenario 'add new participation with carpooling' do
      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      check 'halfday_participation_carpooling'
      fill_in 'carpooling_phone', with: '077 447 58 31'
      click_button 'Inscription'

      expect(page).to have_content 'oui (077 447 58 31)'
    end

    scenario 'add new participation with carpooling (default phone)' do
      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      check 'halfday_participation_carpooling'
      click_button 'Inscription'

      expect(page).to have_content "oui (#{member.phones_array.first})"
    end

    scenario 'remove participation' do
      halfday = halfday_participation.halfday
      participation_text =
        "#{I18n.l(halfday.date, format: :medium).capitalize}, #{halfday.period}"

      expect(page).to have_content participation_text
      click_button 'Effacer', match: :first
      expect(page).not_to have_content participation_text
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
