require 'rails_helper'

describe PDF::Delivery do
  def save_pdf_and_return_strings(delivery, distribution)
    pdf = PDF::Delivery.new(delivery)
    pdf_path = "tmp/delivery-#{Current.acp.name}-#{delivery.date}-#{distribution.name}.pdf"
    pdf.render_file(Rails.root.join(pdf_path))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  context 'Lumiere des Champs' do
    before {
      Current.acp.update!(
        name: 'ldc',
        delivery_pdf_footer: "Si vous avez des remarques ou problèmes, veuillez contacter Julien (079 705 89 01) jusqu'au vendredi midi.")
      set_acp_logo('lumieredeschamps_logo.jpg')
      create_deliveries(48)
    }

    it 'generates invoice with support amount + complements + annual membership' do
      distribution = create(:distribution, name: 'Fleurs Kissling')
      member = create(:member, name: 'Alain Reymond')
      member2 = create(:member, name: 'John Doe')
      member3 = create(:member, name: 'Jame Dane')
      create(:basket_complement,
        id: 1,
        name: 'Oeufs',
        delivery_ids: Delivery.current_year.pluck(:id))
      create(:basket_complement,
        id: 2,
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id))
      membership = create(:membership,
        member: member,
        distribution: distribution,
        basket_size: create(:basket_size, name: 'Grand'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 },
          '1' => { basket_complement_id: 2 }
        })
      membership = create(:membership,
        member: member2,
        distribution: distribution,
        basket_size: create(:basket_size, name: 'Petit'),
        basket_quantity: 2,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, quantity: 2 },
        })
      membership = create(:membership,
        member: member3,
        distribution: distribution,
        basket_size: create(:basket_size, name: 'Moyen'),
        basket_quantity: 0)
      delivery = Delivery.current_year.first
      distribution = membership.distribution

      pdf_strings = save_pdf_and_return_strings(delivery, distribution)

      expect(pdf_strings)
        .to include('Fleurs Kissling')
        .and include(I18n.l delivery.date)
        .and contain_sequence('Grand', 'Petit', 'Oeufs', 'Tomme de Lavaux', 'Signature')
        .and contain_sequence('Alain Reymond', '1', '1', '1')
        .and contain_sequence('John Doe', '2', '2')
        .and contain_sequence('Totaux', '1', '2', '3', '1')
        .and include("Si vous avez des remarques ou problèmes, veuillez contacter Julien (079 705 89 01) jusqu'au vendredi midi.")
      expect(pdf_strings).not_to include 'Jame Dane'
      expect(pdf_strings).not_to include 'Moyen'
    end
  end
end
