require 'rails_helper'

describe Shop::Order do
  describe 'ensure_maximum_weight_limit' do
    let(:product1) {
      create(:shop_product,
        variants_attributes: {
          '0' => {
            name: 'bon',
            weight_in_kg: nil,
            price: 80
          }
        })
    }
    let(:product2) {
      create(:shop_product,
        variants_attributes: {
          '0' => {
            name: '5 kg',
            weight_in_kg: 5,
            price: 16
          }
        })
    }

    specify 'validate maximum weight when defined' do
      Current.acp.update!(shop_order_maximum_weight_in_kg: 10)
      order = build(:shop_order, :pending, items_attributes: {
        '0' => {
          product_id: product1.id,
          product_variant_id: product1.variants.first.id,
          quantity: 100
        },
        '1' => {
          product_id: product2.id,
          product_variant_id: product2.variants.first.id,
          quantity: 3
        }
      })

      expect(order).not_to have_valid(:base)
      expect(order.errors.messages[:base])
        .to include('Le poids total de la commande ne peut pas dépasser 10.0 kg')
    end

    specify 'is valid when equal to the maximum weight limit' do
      Current.acp.update!(shop_order_maximum_weight_in_kg: 10)
      order = build(:shop_order, :pending, items_attributes: {
        '1' => {
          product_id: product2.id,
          product_variant_id: product2.variants.first.id,
          quantity: 2
        }
      })

      expect(order).to have_valid(:base)
    end

    specify 'skip validation when maximum weight is not defined' do
      Current.acp.update!(shop_order_maximum_weight_in_kg: nil)
      order = build(:shop_order, :pending, items_attributes: {
        '1' => {
          product_id: product2.id,
          product_variant_id: product2.variants.first.id,
          quantity: 100
        }
      })

      expect(order).to have_valid(:base)
    end
  end

  describe 'ensure_minimal_amount' do
    let(:product1) {
      create(:shop_product,
        variants_attributes: {
          '0' => {
            name: '1 kg',
            price: 10
          }
        })
    }
    let(:product2) {
      create(:shop_product,
        variants_attributes: {
          '0' => {
            name: '1 kg',
            price: 5
          }
        })
    }

    specify 'validate minimum order amount when defined' do
      Current.acp.update!(shop_order_minimal_amount: 20)
      order = build(:shop_order, :pending, items_attributes: {
        '0' => {
          product_id: product1.id,
          product_variant_id: product1.variants.first.id,
          quantity: 1
        },
        '1' => {
          product_id: product2.id,
          product_variant_id: product2.variants.first.id,
          quantity: 1
        }
      })

      expect(order).not_to have_valid(:base)
      expect(order.amount).to eq(15)
      expect(order.errors.messages[:base])
        .to include("Le montant minimal d'une commande est de CHF 20.00")
    end

    specify 'is valid when equal to the minimal amount' do
      Current.acp.update!(shop_order_minimal_amount: 20)
      order = build(:shop_order, :pending, items_attributes: {
        '0' => {
          product_id: product1.id,
          product_variant_id: product1.variants.first.id,
          quantity: 2
        }
      })

      expect(order).to have_valid(:base)
    end

    specify 'skip validation when maximum weight is not defined' do
      Current.acp.update!(shop_order_minimal_amount: nil)
      order = build(:shop_order, :pending, items_attributes: {
        '1' => {
          product_id: product1.id,
          product_variant_id: product1.variants.first.id,
          quantity: 1
        }
      })

      expect(order).to have_valid(:base)
    end
  end

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

  describe '#confirm!' do
    specify 'change state to pending and update product stock' do
      product = create(:shop_product, variants_attributes: {
        '0' => {
          name: '5 kg',
          price: 16,
          stock: 2
        },
      })
      order = create(:shop_order, :cart, items_attributes: {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        }
      })

      expect { order.confirm! }
        .to change { product.variants.first.reload.stock }.from(2).to(1)
        .and change { order.reload.state }.from('cart').to('pending')
    end
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
