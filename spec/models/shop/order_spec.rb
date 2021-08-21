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

  describe '#invoice!' do
    specify 'create an invoice and set state to invoiced' do
      product = create(:shop_product,
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
      order = create(:shop_order, :pending, items_attributes: {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        },
        '1' => {
          product_id: product.id,
          product_variant_id: product.variants.last.id,
          item_price: 29.55,
          quantity: 2
        }
      })

      travel_to '2021-08-21 09:01:42 +02' do
        expect { order.invoice! }
          .to change { order.reload.state }.from('pending').to('invoiced')
          .and change { Invoice.count }.by(1)
      end

      expect(order.invoice).to have_attributes(
        object_id: order.id,
        object_type: 'Shop::Order',
        amount: BigDecimal(16 + 2 * 29.55, 3),
        date: Date.new(2021, 8, 21),
        sent_at: Time.zone.parse('2021-08-21 09:01:42 +02'))

      expect(order.invoice.items.first).to have_attributes(
        amount: 16,
        description: 'Courge, 5 kg, 1x16.00')
      expect(order.invoice.items.last).to have_attributes(
        amount: BigDecimal(2 * 29.55, 3),
        description: 'Courge, 10 kg, 2x29.55')
    end
  end

  describe '#cancel!' do
    specify 'cancel the invoice and set state back to pending' do
      order = create(:shop_order, :pending)
      invoice = order.invoice!

      expect { order.cancel! }
        .to change { order.reload.state }.from('invoiced').to('pending')
        .and change { invoice.reload.state }.from('open').to('canceled')
      expect(order.invoice).to be_nil
    end
  end
end
