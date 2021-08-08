require 'rails_helper'

describe Shop::Order do
  specify 'update amount when removing item' do
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
        quantity: 1
      },
      '1' => {
        product_id: product.id,
        product_variant_id: product.variants.last.id,
        quantity: 1
      }
    })

    expect {
      order.update!(items_attributes: {
        '0' => {
          id: order.items.first.id,
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        },
        '1' => {
          id: order.items.last.id,
          product_id: product.id,
          product_variant_id: product.variants.last.id,
          quantity: 1,
          _destroy: true
        }
      })
    }.to change { order.reload.amount }.from(46).to(16)
  end
end
