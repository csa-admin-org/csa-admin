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

  describe '.available_for' do
    specify 'returns products that are available' do
      delivery = create(:delivery)
      product1 = create(:shop_product, available: true)
      product2 = create(:shop_product, available: false)

      expect(Shop::Product.available_for(delivery)).to contain_exactly(product1)
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
  end
end
