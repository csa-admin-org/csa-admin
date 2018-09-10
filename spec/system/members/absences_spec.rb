require 'rails_helper'

describe 'Absences' do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
    login(member)
  end

  it 'adds new absence' do
    visit '/'

    click_on 'Absences'

    fill_in 'Début', with: 2.weeks.from_now
    fill_in 'Fin', with: 3.weeks.from_now

    click_button 'Envoyer'

    expect(page).to have_content('Merci de nous avoir prévenus!')
    expect(page).to have_content "#{I18n.l(2.weeks.from_now.to_date)} – #{I18n.l(3.weeks.from_now.to_date)}"
  end

  it 'lists previous absences' do
    member.absences.build(
      started_on: 3.weeks.ago,
      ended_on: 2.weeks.ago).save!(validate: false)

    visit '/absences'

    expect(page).to have_content "#{I18n.l(3.weeks.ago.to_date)} – #{I18n.l(2.weeks.ago.to_date)}"
  end
end
