require 'rails_helper'

describe PDF::Delivery do
  def save_pdf_and_return_strings(delivery, depot)
    pdf = PDF::Delivery.new(delivery)
    pdf_path = "tmp/delivery-#{Current.acp.name}-#{delivery.date}-#{depot.name}.pdf"
    pdf.render_file(Rails.root.join(pdf_path))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  context 'Lumiere des Champs' do
    before {
      Current.acp.update!(
        name: 'ldc',
        logo_url: 'https://d2ibcm5tv7rtdh.cloudfront.net/lumieredeschamps/logo.jpg',
        delivery_pdf_footer: "Si vous avez des remarques ou problèmes, veuillez contacter Julien (079 705 89 01) jusqu'au vendredi midi.")
      create_deliveries(48)
    }

    it 'generates invoice with support amount + complements + annual membership' do
      depot = create(:depot, name: 'Fleurs Kissling')
      delivery = Delivery.current_year.first
      member = create(:member, name: 'Alain Reymond')
      member2 = create(:member, name: 'John Doe')
      member3 = create(:member, name: 'Jame Dane')
      member4 = create(:member, name: 'Missing Joe')
      create(:basket_complement,
        id: 1,
        name: 'Oeufs',
        delivery_ids: Delivery.current_year.pluck(:id))
      create(:basket_complement,
        id: 2,
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id))
      small_basket = create(:basket_size, name: 'Petit')
      membership = create(:membership,
        member: member,
        depot: depot,
        basket_size: create(:basket_size, name: 'Grand'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 },
          '1' => { basket_complement_id: 2 }
        })
      membership = create(:membership,
        member: member2,
        depot: depot,
        basket_size: small_basket,
        basket_quantity: 2,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, quantity: 2 },
        })
      membership = create(:membership,
        member: member3,
        depot: depot,
        basket_size: create(:basket_size, name: 'Moyen'),
        basket_quantity: 0)
      membership = create(:membership,
        member: member4,
        depot: depot,
        basket_size: small_basket,
        basket_quantity: 1,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, quantity: 3 },
        })
      create(:absence,
        admin: create(:admin),
        member: member4,
        started_on: delivery.date - 1.day,
        ended_on: delivery.date + 1.day)

      pdf_strings = save_pdf_and_return_strings(delivery, depot)
      expect(pdf_strings)
        .to include('Fleurs Kissling')
        .and include(I18n.l delivery.date)
        .and contain_sequence('Grand', 'Petit', 'Oeufs', 'Tomme de Lavaux')
        .and contain_sequence('Totaux (dépôt)', '1', '2', '3', '1', 'Signature')
        .and contain_sequence('Alain Reymond', '1', '1', '1')
        .and contain_sequence('John Doe', '2', '2')
        .and contain_sequence('Missing Joe', '–', '–', '–', '–', 'ABSENT')
        .and include("Si vous avez des remarques ou problèmes, veuillez contacter Julien (079 705 89 01) jusqu'au vendredi midi.")
      expect(pdf_strings).not_to include 'Jame Dane'
      expect(pdf_strings).not_to include 'Moyen'
    end
  end
end
