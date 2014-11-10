require 'rails_helper'

feature 'members page' do
  fixtures :members, :halfday_works
  before { Capybara.app_host = 'http://membres.example.com' }

  context 'existing member token' do
    before { visit "/#{members(:john).token}" }
    scenario 'add new halfday work' do
      check 'halfday_work_period_am'
      check 'halfday_work_period_pm'
      fill_in 'halfday_work_participants_count', with: 3
      click_button 'Inscription'

      expect(page)
        .to have_content "#{I18n.l Date.today, format: :long}8:00 - 17:303"
    end

    scenario 'remove halfday work' do
      date = halfday_works(:new_am).date
      date_text = I18n.l(date, format: :long)

      expect(page).to have_content date_text
      click_button 'Effacer', match: :first
      expect(page).not_to have_content date_text
    end
  end

  context 'non-existing member token' do
    scenario 'redirect to recover token page' do
      visit '/wrong_token'
      expect(current_path).to eq '/token/recover'
    end
  end
end
