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
      expect(order.weight_in_kg).to eq(15)
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

    specify 'skip validation when edited by admin' do
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
      order.admin = create(:admin)

      expect(order).to have_valid(:base)
      expect(order.weight_in_kg).to eq(15)
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

    specify 'skip validation when edited by admin' do
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
      order.admin = create(:admin)

      expect(order).to have_valid(:base)
      expect(order.amount).to eq(15)
    end
  end

  specify 'support polymorphic delivery association' do
    delivery = create(:delivery)
    order = create(:shop_order, delivery_gid: delivery.gid)
    special_delivery = create(:shop_special_delivery)
    special_order = create(:shop_order, delivery_gid: special_delivery.gid)

    expect(order.delivery_gid).to eq "gid://acp-admin/Delivery/#{delivery.id}"
    expect(special_order.delivery_gid).to eq "gid://acp-admin/Shop::SpecialDelivery/#{special_delivery.id}"

    expect(Shop::Order._delivery_gid_eq(delivery.gid)).to eq [order]
    expect(Shop::Order._delivery_gid_eq(special_delivery.gid)).to eq [special_order]
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
    specify 'change state to pending and decrement product stock' do
      product = create(:shop_product, variants_attributes: {
        '0' => {
          name: '5 kg',
          price: 16,
          stock: 2
        },
        '1' => {
          name: '10 kg',
          price: 30,
          stock: 4
        }
      })
      order = create(:shop_order, :cart, items_attributes: {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        },
        '1' => {
          product_id: product.id,
          product_variant_id: product.variants.last.id,
          quantity: 2,
        }
      })

      expect { order.confirm! }
        .to change { product.variants.first.reload.stock }.from(2).to(1)
        .and change { product.variants.last.reload.stock }.from(4).to(2)
        .and change { order.reload.state }.from('cart').to('pending')
    end

    specify 'persist the depot', sidekiq: :inline do
      member = create(:member, :active)
      depot = member.current_membership.depot
      order = create(:shop_order, :cart, member: member)

      expect(order.depot).to eq(depot)

      expect { order.confirm! }
        .to change { order.reload.depot_id }.from(nil).to(depot.id)
    end
  end

  describe '#update!' do
    specify 'update product stock when pending order is changing' do
      product = create(:shop_product, variants_attributes: {
        '0' => {
          name: '5 kg',
          price: 16,
          stock: 2
        },
        '1' => {
          name: '10 kg',
          price: 30,
          stock: 4
        },
        '2' => {
          name: '15 kg',
          price: 35,
          stock: 5
        },
        '3' => {
          name: '20 kg',
          price: 40,
          stock: 4
        }
      })
      order = create(:shop_order, :cart, items_attributes: {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        },
        '1' => {
          product_id: product.id,
          product_variant_id: product.variants.second.id,
          quantity: 2,
        },
        '2' => {
          product_id: product.id,
          product_variant_id: product.variants.third.id,
          quantity: 3
        },
        '3' => {
          product_id: product.id,
          product_variant_id: product.variants.last.id,
          quantity: 3
        }
      })
      order.confirm!
      order.reload

      expect {
        order.update!(items_attributes: {
          '0' => {
            id: order.items.first.id,
            quantity: 2
          },
          '1' => {
            id: order.items.second.id,
            quantity: 1,
          },
          '2' => {
            id: order.items.third.id,
            quantity: 0
          },
          '3' => {
            id: order.items.last.id,
            quantity: 3,
            _destroy: 1
          }
        })
      }
        .to change { product.variants.first.reload.stock }.from(1).to(0)
        .and change { product.variants.second.reload.stock }.from(2).to(3)
        .and change { product.variants.third.reload.stock }.from(2).to(5)
        .and change { product.variants.last.reload.stock }.from(1).to(4)

      expect(order.items.size).to eq(2)
    end

    specify 'persist the depot', sidekiq: :inline do
      member = create(:member, :active)
      depot = member.current_membership.depot
      order = create(:shop_order, :cart, member: member)

      expect(order.depot).to eq(depot)

      expect { order.confirm! }
        .to change { order.reload.depot_id }.from(nil).to(depot.id)
    end
  end

  describe '#unconfirm!' do
    specify 'change state to pending and increment product stock' do
      product = create(:shop_product, variants_attributes: {
        '0' => {
          name: '5 kg',
          price: 16,
          stock: 2
        },
        '1' => {
          name: '10 kg',
          price: 30,
          stock: 4
        }
      })
      order = create(:shop_order, :cart, items_attributes: {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        },
        '1' => {
          product_id: product.id,
          product_variant_id: product.variants.last.id,
          quantity: 4,
        }
      })
      order.confirm!
      order.reload

      expect { order.unconfirm! }
        .to change { product.variants.first.reload.stock }.from(1).to(2)
        .and change { product.variants.last.reload.stock }.from(0).to(4)
        .and change { order.reload.state }.from('pending').to('cart')
    end

    specify 'persist the depot', sidekiq: :inline do
      member = create(:member, :active)
      depot = member.current_membership.depot
      order = create(:shop_order, :cart, member: member)

      expect(order.depot).to eq(depot)

      expect { order.confirm! }
        .to change { order.reload.depot_id }.from(nil).to(depot.id)
    end
  end

  describe '#percentage' do
    specify 'set percentage (reduction)' do
      product = create(:shop_product)
      order = create(:shop_order, :cart,
        amount_percentage: -15.5,
        items_attributes: {
          '0' => {
            product_id: product.id,
            product_variant_id: product.variants.first.id,
            item_price: 10,
            quantity: 1
          },
        })

      expect(order).to have_attributes(
        amount_before_percentage: 10,
        amount_percentage: -15.5,
        amount: 8.45)
    end

    specify 'set percentage (increase)' do
      product = create(:shop_product)
      order = create(:shop_order, :cart,
        amount_percentage: 21.5,
        items_attributes: {
          '0' => {
            product_id: product.id,
            product_variant_id: product.variants.first.id,
            item_price: 10,
            quantity: 1
          },
        })

      expect(order).to have_attributes(
        amount_before_percentage: 10,
        amount_percentage: 21.5,
        amount: 12.15)
    end
  end

  describe '#auto_invoice!' do
    specify 'auto invoice after delivery date' do
      delivery = create(:delivery, date: 3.days.from_now)
      order = create(:shop_order, :pending, delivery_gid: delivery.gid)
      Current.acp.update!(shop_order_automatic_invoicing_delay_in_days: 3)

      travel 5.days do
        expect { order.auto_invoice! }.not_to change { order.reload.state }
      end

      travel 6.days do
        expect {
          order.auto_invoice!
        }.to change { order.reload.state }.from('pending').to('invoiced')
      end
    end

    specify 'auto invoice before delivery date' do
      delivery = create(:delivery, date: Date.today)
      order = create(:shop_order, :pending, delivery_gid: delivery.gid)
      Current.acp.update!(shop_order_automatic_invoicing_delay_in_days: -2)

      travel -3.days do
        expect { order.auto_invoice! }.not_to change { order.reload.state }
      end

      travel -2.days do
        expect { order.auto_invoice! }
          .to change { order.reload.state }.from('pending').to('invoiced')
      end
    end

    specify 'auto invoice the delivery date' do
      delivery = create(:delivery, date: Date.today)
      order = create(:shop_order, :pending, delivery_gid: delivery.gid)
      Current.acp.update!(shop_order_automatic_invoicing_delay_in_days: 0)

      expect { order.auto_invoice! }
        .to change { order.reload.state }.from('pending').to('invoiced')
    end

    specify 'do nothing when no delay configured' do
      delivery = create(:delivery, date: Date.today)
      order = create(:shop_order, :pending, delivery_gid: delivery.gid)
      Current.acp.update!(shop_order_automatic_invoicing_delay_in_days: nil)

      expect { order.auto_invoice! }.not_to change { order.reload.state }
    end

    specify 'do nothing for cart order' do
      Current.acp.update!(shop_order_automatic_invoicing_delay_in_days: 0)

      order = create(:shop_order, :cart)
      expect { order.auto_invoice! }.not_to change { order.reload.state }
    end

    specify 'do nothing for invoiced order' do
      Current.acp.update!(shop_order_automatic_invoicing_delay_in_days: 0)

      order = create(:shop_order, :invoiced)
      expect { order.auto_invoice! }.not_to change { order.reload.state }
    end
  end

  describe '#invoice!' do
    specify 'create an invoice and set state to invoiced', sidekiq: :inline do
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
        entity_id: order.id,
        entity_type: 'Shop::Order',
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
    specify 'cancel the invoice and set state back to pending', sidekiq: :inline do
      order = create(:shop_order, :pending)
      invoice = order.invoice!

      expect { order.cancel! }
        .to change { order.reload.state }.from('invoiced').to('pending')
        .and change { invoice.reload.state }.from('open').to('canceled')
      expect(order.invoice).to be_nil
    end
  end

  specify 'allow invoice with negative amount' do
    product = create(:shop_product)
    order = create(:shop_order, :pending, items_attributes: {
      '0' => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        item_price: 4,
        quantity: 1
      },
      '1' => {
        product_id: product.id,
        product_variant_id: product.variants.last.id,
        item_price: -5,
        quantity: 1
      }
    })
    expect(order.amount).to eq(-1)
  end
end
