require 'rails_helper'

describe PDF::Shop::Delivery do
  def save_pdf_and_return_strings(delivery, order: nil)
    pdf = PDF::Shop::Delivery.new(delivery, order: order)
    # pdf_path = "tmp/shop-delivery-#{Current.acp.name}-#{delivery.date}.pdf"
    # pdf.render_file(Rails.root.join(pdf_path))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  context 'P2R' do
    before {
      Current.acp.update!(
        name: 'P2R',
        logo_url: 'https://d2ibcm5tv7rtdh.cloudfront.net/p2r/logo.jpg',
        shop_delivery_pdf_footer: "Facture envoyée séparément par email.")
    }

    it 'generates delivery notes for all orders' do
      depot1 = create(:depot, name: 'Cery')
      depot2 = create(:depot, name: 'Chailly')
      member1 = create(:member, name: 'James Doe')
      member2 = create(:member, name: 'John Doe')
      create(:membership, member: member1, depot: depot1)
      create(:membership, member: member2, depot: depot2)
      delivery = Delivery.current_year.first

      producer = create(:shop_producer, name: 'La ferme du Village')
      product = create(:shop_product,
        producer: producer,
        name: 'Courge',
        variants_attributes: {
          '0' => {
            name: '5 kg',
            price: 16
          },
          '1' => {
            name: '10 kg',
            price: 30
          }
        })
      order = create(:shop_order, :pending,
        delivery: delivery,
        member: member1,
        items_attributes: {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        },
        '1' => {
          product_id: product.id,
          product_variant_id: product.variants.last.id,
          quantity: 2
        }
      })

      pdf_strings = save_pdf_and_return_strings(delivery)
      expect(pdf_strings)
        .to include('Cery PUBLIC')
        .and include('James Doe')
        .and include(I18n.l delivery.date)
        .and include('Bulletin de livraison')
        .and include('Quantité', 'Produit')
        .and include('2', 'Courge, 10 kg, La ferme du Village')
        .and include('1', 'Courge, 5 kg, La ferme du Village')
        .and include('Facture envoyée séparément par email.')

      expect(pdf_strings).not_to include 'Chailly'
      expect(pdf_strings).not_to include 'John Doe'
    end

    it 'generates delivery for a specific order with multiple pages' do
      depot= create(:depot, name: 'Cery')
      member = create(:member, name: 'James Doe', shop_depot: depot)
      delivery = create(:delivery)

      order = create(:shop_order, :pending,
        delivery: delivery,
        member: member,
        items_attributes: 27.times.map { |i|
          product = create(:shop_product, name: "Produit #{i}")
          [
            i,
            {
              product_id: product.id,
              product_variant_id: product.variants.first.id,
              quantity: 1
            }
          ]
        }.to_h)

      pdf_strings = save_pdf_and_return_strings(delivery, order: order)
      expect(pdf_strings)
        .to include('Cery PUBLIC')
        .and include('James Doe')
        .and include(I18n.l delivery.date)
        .and include('1 / 2')
        .and include('2 / 2')
    end
  end
end
