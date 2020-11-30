require 'rails_helper'

describe 'Mail Templates' do
  def iframe(id = 'mail_preview_fr')
    src = page.find("iframe##{id}")[:srcdoc]
    Capybara::Node::Simple.new(src)
  end

  specify 'modify and preview' do
    mail_template = travel_to('2020-03-24') do
      create(:membership,
        basket_size: create(:basket_size, id: 33, name: 'Eveil'))
      MailTemplate.create!(title: 'member_activated')
    end

    login create(:admin, email: 'thibaud@thibaud.gg')

    visit mail_template_path(mail_template)
    click_link 'Modifier'

    check 'Envoyé'
    fill_in 'Sujet', with: 'Bienvenue {{ member.name }}!!'
    fill_in 'Contenu', with: '<p>Panier:: {{ membership.basket_size.name }}</p>'

    expect {
      travel_to('2020-03-25') do
        click_button 'Mettre à jour Template Email'
      end
    }.to change(Audit, :count).by(1)

    click_link 'Membre activé'

    expect(page).to have_selector 'h2#page_title', text: 'Membre activé'
    expect(page).to have_content('Envoyé Oui')
    expect(iframe).to have_selector 'h1', text: 'Bienvenue Jane Doe!!'
    expect(iframe).to have_selector 'p', text: 'Panier:: Eveil'
  end
end
