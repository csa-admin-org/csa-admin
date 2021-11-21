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

  specify 'validate available stock on creation (pending)' do
    product = create(:shop_product, variants_attributes: {
      '0' => {
        name: '5 kg',
        price: 16,
        stock: 2
      },
    })
    order = build(:shop_order, :pending, items_attributes: {
      '0' => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 3
      }
    })

    order.validate
    expect(order.items.first.errors[:quantity])
      .to eq(['doit être inférieur ou égal à 2'])
  end

  specify 'validate and update stock on update (pending)' do
    product = create(:shop_product, variants_attributes: {
      '0' => {
        name: '5 kg',
        price: 16,
        stock: 2
      },
    })
    order = create(:shop_order, :pending, items_attributes: {
      '0' => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 1
      }
    })

    expect(product.variants.first.reload.stock).to eq(1)

    order.reload
    order.update(items_attributes: {
      '0' => {
        id: order.items.first.id,
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 3
      }
    })

    expect(order.items.first.errors[:quantity])
      .to eq(['doit être inférieur ou égal à 2'])

    order.update!(items_attributes: {
      '0' => {
        id: order.items.first.id,
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 2
      }
    })

    expect(product.variants.first.reload.stock).to eq(0)
  end

  specify 'validate product is available for delivery' do
    complement = create(:basket_complement)
    delivery = create(:delivery, basket_complement_ids: [])
    product = create(:shop_product,
      available: true,
      basket_complement: complement,
      variants_attributes: {
        '0' => {
          name: '100g',
          price: 5
        }
      })

      order = build(:shop_order, :pending,
        delivery: delivery,
        items_attributes: {
          '0' => {
            product_id: product.id,
            product_variant_id: product.variants.first.id,
            quantity: 1
          }
        })

      order.validate
      expect(order.items.first.errors[:product])
        .to eq(["N'est pas disponible pour cette livraison"])
  end

  specify 'releases stock when deleting order (pending' do
    product = create(:shop_product, variants_attributes: {
      '0' => {
        name: '5 kg',
        price: 16,
        stock: 3
      },
    })
    order = create(:shop_order, :pending, items_attributes: {
      '0' => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 2
      }
    })

    expect(product.variants.first.reload.stock).to eq(1)

    expect { order.destroy! }
      .to change { product.variants.first.reload.stock }.by(2)
  end
end
