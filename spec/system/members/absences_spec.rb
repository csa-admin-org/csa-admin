require 'rails_helper'

describe 'Absences' do
  around { |e| travel_to('2021-06-15') { e.run } }

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
    expect(page).to have_content('Ces paniers ne sont pas remboursés')
    expect(page).to have_content "#{I18n.l(2.weeks.from_now.to_date)} – #{I18n.l(3.weeks.from_now.to_date)}"
    expect(member.absences.last.session_id).to eq(member.sessions.last.id)
  end

  it 'does not show explanation when absences are not billed' do
    current_acp.update!(absences_billed: false)

    visit '/absences'

    expect(page).not_to have_content('Ces paniers ne sont pas remboursés')
  end

  it 'lists previous absences' do
    member.absences.build(
      started_on: 3.weeks.ago,
      ended_on: 2.weeks.ago).save!(validate: false)

    visit '/absences'

    expect(page).to have_content "#{I18n.l(3.weeks.ago.to_date)} – #{I18n.l(2.weeks.ago.to_date)}"
  end

  it 'redirects to billing when absence is not a feature' do
    current_acp.update!(features: [])

    visit '/absences'

    expect(current_path).to eq '/billing'
  end
end
