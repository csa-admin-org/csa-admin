require 'rails_helper'

describe PDF::Delivery do
  def save_pdf_and_return_strings(delivery, depot)
    pdf = PDF::Delivery.new(delivery)
    # pdf_path = "tmp/delivery-#{Current.acp.name}-#{delivery.date}-#{depot.name}.pdf"
    # pdf.render_file(Rails.root.join(pdf_path))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  context 'Lumiere des Champs' do
    before {
      Current.acp.update!(
        name: 'ldc',
        logo_url: 'https://d2ibcm5tv7rtdh.cloudfront.net/lumieredeschamps/logo.jpg',
        delivery_pdf_footer: "Si vous avez des remarques ou problèmes, veuillez contacter Julien (079 705 89 01) jusqu'au vendredi midi.")
    }

    it 'generates invoice with support amount + complements + annual membership' do
      depot = create(:depot, name: 'Fleurs Kissling')
      delivery = create(:delivery, shop_open: false)
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
        .to include('Fleurs Kissling PUBLIC')
        .and include(I18n.l delivery.date)
        .and contain_sequence('Petit PUBLIC', 'Grand PUBLIC', 'Oeufs PUBLIC', 'Tomme de Lavaux PUBLIC')
        .and contain_sequence('Totaux (dépôt)', '2', '1', '3', '1', 'Signature')
        .and contain_sequence('Alain Reymond', '1', '1', '1')
        .and contain_sequence('John Doe', '2', '2')
        .and contain_sequence('Missing Joe', '–', '–', '–', '–', 'ABSENT·E')
        .and contain_sequence("Si vous avez des remarques ou problèmes, veuillez contacter Julien (079 705 89 01) jusqu'au vendredi midi.")
      expect(pdf_strings).not_to include 'Jame Dane'
      expect(pdf_strings).not_to include 'Moyen PUBLIC'
    end

    specify 'includes announcement' do
      depot = create(:depot, name: 'Fleurs Kissling')
      delivery = create(:delivery)
      create(:membership, depot: depot)

      Announcement.create!(
        text: 'Ramenez les sacs!',
        depot_ids: [depot.id],
        delivery_ids: [delivery.id])

      pdf_strings = save_pdf_and_return_strings(delivery, depot)

      expect(pdf_strings)
        .to include('Fleurs Kissling PUBLIC')
        .and include('Ramenez les sacs!')
    end

    specify 'includes shop orders' do
      Current.acp.update!(features: ['shop'])
      depot = create(:depot, name: 'Fleurs Kissling')
      delivery = create(:delivery, shop_open: true)
      member = create(:member, name: 'Alain Reymond')
      member2 = create(:member, name: 'John Doe')
      basket_complement = create(:basket_complement,
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
          '1' => { basket_complement_id: 2 }
        })
      membership = create(:membership,
        member: member2,
        depot: depot,
        basket_size: small_basket,
        basket_quantity: 2,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 2, quantity: 2 },
        })

      product = create(:shop_product,
        name: 'Oeufs',
        basket_complement: basket_complement,
        variants_attributes: {
          '0' => {
            name: '6x',
            price: 3.8
          },
        })
      product2 = create(:shop_product,
        name: 'Farine',
        variants_attributes: {
          '0' => {
            name: '500g',
            price: '4'
          },
        })
      order = create(:shop_order, :pending,
        delivery: delivery,
        member: member,
        depot: depot,
        items_attributes: {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 2
        },
      })
      order = create(:shop_order, :pending,
        delivery: delivery,
        member: member2,
        depot: depot,
        items_attributes: {
        '0' => {
          product_id: product2.id,
          product_variant_id: product2.variants.first.id,
          quantity: 2
        },
      })

      pdf_strings = save_pdf_and_return_strings(delivery, depot)
      expect(pdf_strings)
        .to include('Fleurs Kissling PUBLIC')
        .and include(I18n.l delivery.date)
        .and contain_sequence('Petit PUBLIC', 'Grand PUBLIC', 'Oeufs PUBLIC', 'Tomme de Lavaux PUBLIC', "Commande d'épicerie")
        .and contain_sequence('Totaux (dépôt)', '2', '1', '2', '3', '2', 'Signature')
        .and contain_sequence('Alain Reymond', '1', '2', '1', 'X')
        .and contain_sequence('John Doe', '2', '2', 'X')
    end
  end
end
