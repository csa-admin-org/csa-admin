require 'rails_helper'

describe Shop::Product do
  specify 'validate single variant when associated to a basket complement' do
    product = build(:shop_product,
      basket_complement: create(:basket_complement),
      variants_attributes: {
        '0' => {
          name: '100g',
          price: 5
        },
        '1' => {
          name: '200g',
          price: 10
        }
      })

    expect(product).not_to have_valid(:variants)
    expect(product.errors.messages[:variants])
      .to include(': une seule variante est autorisée quand le produit est lié à un complément panier')
  end

  specify 'validate at least one available variant' do
    product = create(:shop_product,
      variants_attributes: {
        '0' => {
          name: '100g',
          price: 5
        }
     })

    product.update(variants_attributes: {
      '0' => {
        id: product.variants.first.id,
        name: '100g',
        price: 5,
        available: false
      }
    })

    expect(product).not_to have_valid(:base)
    expect(product.errors.messages[:base])
      .to include('Au moins une variante doit être disponible')

    expect(product.variants.available).to be_present
  end

  describe '.available_for' do
    specify 'returns products that are available' do
      delivery = create(:delivery)
      product1 = create(:shop_product, available: true)
      product2 = create(:shop_product, available: false)

      expect(Shop::Product.available_for(delivery))
        .to contain_exactly(product1)
    end

    specify 'returns products that available and have basket complement available at this delivery' do
      complement = create(:basket_complement)
      delivery1 = create(:delivery, basket_complement_ids: [complement.id])
      delivery2 = create(:delivery)
      product1 = create(:shop_product, available: true)
      product2 = create(:shop_product, available: false)
      product3 = create(:shop_product,
        available: true,
        basket_complement: complement,
        variants_attributes: {
          '0' => {
            name: '100g',
            price: 5
          }
        })

      expect(Shop::Product.available_for(delivery1)).to contain_exactly(product1, product3)
      expect(Shop::Product.available_for(delivery2)).to contain_exactly(product1)
    end

    specify 'returns products that are available for the given depot' do
      delivery = create(:delivery)
      depot1 = create(:depot)
      depot2 = create(:depot)

      product1 = create(:shop_product,
        available_for_depot_ids: [depot1.id, depot2.id])
      product2 = create(:shop_product,
        unavailable_for_depot_ids: [depot1.id])

      expect(Shop::Product.available_for(delivery, depot1))
        .to contain_exactly(product1)
      expect(Shop::Product.available_for(delivery, depot2))
        .to contain_exactly(product1, product2)
    end

    specify 'returns products that are available for the given delivery', freeze: '2023-01-01' do
      delivery1 = create(:delivery, date: '2023-02-01')
      delivery2 = create(:delivery, date: '2023-03-01')

      product1 = create(:shop_product,
        available_for_delivery_ids: [delivery1.id, delivery2.id])
      product2 = create(:shop_product,
        unavailable_for_delivery_ids: [delivery1.id])

      expect(Shop::Product.available_for(delivery1))
        .to contain_exactly(product1)
      expect(Shop::Product.available_for(delivery2))
        .to contain_exactly(product1, product2)
    end
  end

  specify 'null producer' do
    product = create(:shop_product, producer: nil)
    expect(product.producer).to eq Shop::NullProducer.instance
  end
end
