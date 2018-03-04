require 'rails_helper'

describe 'members page' do
  let!(:member) { create(:member, :active, phones: "76 332 33 11") }
  let!(:halfday_participation) { create(:halfday_participation, member: member) }

  before { Capybara.app_host = 'http://membres.ragedevert.test' }

  context 'existing member token' do
    let!(:halfday) { create(:halfday, date: 4.days.from_now) }
    before { visit "/#{member.token}" }

    it 'adds new participation' do
      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      click_button 'Inscription'

      expect(page)
        .to have_content "#{I18n.l(halfday.date, format: :long).capitalize}, #{halfday.period}"
      within('ol.halfdays') do
        expect(page).not_to have_content "covoiturage"
      end
    end

    it 'adds new participation with carpooling' do
      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      check 'halfday_participation_carpooling'
      fill_in 'carpooling_phone', with: '+41 77 447 58 31'
      click_button 'Inscription'

      within('ol.halfdays') do
        expect(page).to have_content "covoiturage"
      end
    end

    it 'adds new participation with carpooling (default phone)' do
      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      check 'halfday_participation_carpooling'
      click_button 'Inscription'

      within('ol.halfdays') do
        expect(page).to have_content "covoiturage"
      end
    end

    it 'removes participation' do
      halfday = halfday_participation.halfday
      participation_text =
        "#{I18n.l(halfday.date, format: :long).capitalize}, #{halfday.period}"

      expect(page).to have_content participation_text
      click_link 'annuler', match: :first
      expect(page).not_to have_content participation_text
    end
  end

  context 'wrong member token' do
    let(:email) { member.emails_array.first }

    it 'recovers token from email' do
      visit '/wrong_token'
      expect(current_path).to eq '/token/recover'

      fill_in 'email', with: email
      click_button 'Retrouver'

      last_email = ActionMailer::Base.deliveries.last
      expect(last_email.to).to eq [email]
      expect(last_email.body)
        .to include "membres.ragedevert.ch/#{member.token}"

      expect(current_path).to eq '/token/recover'
      expect(page).to have_content 'Merci'
    end
  end
end
