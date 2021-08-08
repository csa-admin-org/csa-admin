require 'rails_helper'

describe Shop::OrderItem do
  specify 'set product variant price by default' do
    product = create(:shop_product, variants_attributes: {
      '0' => {
        name: '5 kg',
        price: 16
      },
      '1' => {
        name: '10 kg',
        price: 30
      }
    })
    order = create(:shop_order, items_attributes: {
      '0' => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        item_price: '',
        quantity: 2
      },
      '1' => {
        product_id: product.id,
        product_variant_id: product.variants.last.id,
        item_price: '28',
        quantity: 3
      }
    })

    expect(order).to have_attributes(
      amount: 2 * 16 + 3 * 28)
    expect(order.items.first).to have_attributes(
      item_price: 16,
      quantity: 2,
      amount: 2 * 16)
    expect(order.items.last).to have_attributes(
      item_price: 28,
      quantity: 3,
      amount: 3 * 28)
  end
end
