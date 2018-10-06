require 'rails_helper'

describe 'Halfday Participation' do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
    login(member)
  end

  it 'adds new participation' do
    halfday = create(:halfday, date: 4.days.from_now)

    visit '/'

    choose "halfday_participation_halfday_id_#{halfday.id}"
    fill_in 'halfday_participation_participants_count', with: 3
    click_button 'Inscription'

    expect(page).to have_content('Merci pour votre inscription!')
    expect(page)
      .to have_content "#{I18n.l(halfday.date, format: :long).capitalize}, #{halfday.period}"
    within('ol.main') do
      expect(page).not_to have_content 'covoiturage'
    end
    expect(member.halfday_participations.last.session_id).to eq(member.sessions.last.id)
  end

  it 'adds new participation with carpooling' do
    halfday = create(:halfday, date: 4.days.from_now)

    visit '/'

    choose "halfday_participation_halfday_id_#{halfday.id}"
    fill_in 'halfday_participation_participants_count', with: 3
    check 'halfday_participation_carpooling'
    fill_in 'halfday_participation_carpooling_phone', with: '077 447 58 31'
    fill_in 'halfday_participation_carpooling_city', with: 'La Chaux-de-Fonds'
    click_button 'Inscription'

    expect(page).to have_content('Merci pour votre inscription!')
    within('ol.main') do
      expect(page).to have_content 'covoiturage'
    end
    expect(HalfdayParticipation.last).to have_attributes(
      carpooling_phone: '+41774475831',
      carpooling_city: 'La Chaux-de-Fonds')
  end

  it 'adds new participation with carpooling (default phone)' do
    halfday = create(:halfday, date: 4.days.from_now)

    visit '/'

    choose "halfday_participation_halfday_id_#{halfday.id}"
    fill_in 'halfday_participation_participants_count', with: 3
    check 'halfday_participation_carpooling'

    click_button 'Inscription'

    expect(page).to have_content('Merci pour votre inscription!')
    within('ol.main') do
      expect(page).to have_content 'covoiturage'
    end
  end

  it 'deletes a participation' do
    halfday = create(:halfday_participation, member: member).halfday

    visit '/'

    part_text = "#{I18n.l(halfday.date, format: :long).capitalize}, #{halfday.period}"

    expect(page).to have_content part_text
    click_link 'annuler', match: :first
    expect(page).not_to have_content part_text
    expect(page).not_to have_content "Pour des raisons d'organisation,"
  end

  it 'cannot delete a participation when deadline is overdue' do
    Current.acp.update!(
      halfday_i18n_scope: 'basket_preparation',
      halfday_participation_deletion_deadline_in_days: 30)
    halfday = create(:halfday, date: 29.days.from_now)
    create(:halfday_participation,
      member: member,
      halfday: halfday,
      created_at: 25.hours.ago)

    visit '/'

    part_text = "#{I18n.l(halfday.date, format: :long).capitalize}, #{halfday.period}"

    expect(page).to have_content part_text
    expect(page).not_to have_content 'annuler'
    expect(page).to have_content "Pour des raisons d'organisation, les inscriptions aux mises en panier qui ont lieu dans moins de 30 jours ne peuvent plus être annulées. En cas d'empêchement, merci de nous contacter."
  end
end
