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
end
