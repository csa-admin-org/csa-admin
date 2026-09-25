# frozen_string_literal: true

require "test_helper"

class Shop::OrderGroupTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-04-10"
    members(:jane).update!(shop_invoice_period: "month")
    @first = create_shop_order(
      delivery: deliveries(:monday_1),
      amount_percentage: 10,
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_500).id,
          item_price: 0.05,
          quantity: 1
        },
        "1" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_1000).id,
          item_price: 0.05,
          quantity: 1
        }
      })
    @second = create_shop_order(
      delivery: deliveries(:thursday_1),
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_1000).id,
          item_price: 10,
          quantity: 1
        }
      })
  end

  test "one invoice, one section per order, percentage rounded once on the section" do
    group = Shop::OrderGroup.invoice_orders!([ @second, @first ])
    invoice = group.invoice

    assert_equal "Shop::OrderGroup", invoice.entity_type
    assert_equal "2024-04", group.period
    assert_nil invoice.amount_percentage
    assert_equal Date.new(2024, 4, 10), invoice.date
    assert_equal [ @first.id, @second.id ], group.orders.order(:id).pluck(:id)
    assert @first.reload.invoiced?
    assert @second.reload.invoiced?
    assert_equal invoice, @first.invoice
    assert_equal invoice, @second.invoice

    amounts = invoice.items.order(:id).pluck(:description, :amount)
    first_items = @first.items.order(:id)
    assert_equal [
      [ @first.invoice_section_description, 0 ],
      [ first_items.first.description, 0.05 ],
      [ first_items.second.description, 0.05 ],
      [ @first.invoice_percentage_description, 0.01 ],
      [ @second.invoice_section_description, 0 ],
      [ @second.items.first.description, 10 ]
    ], amounts
    assert_equal 10.11, invoice.amount
    assert_equal 0.12, @first.amount
    assert_equal 0.01, @first.invoice_percentage_delta
  end

  test "cancel returns every order to pending so the period can be invoiced again" do
    group = Shop::OrderGroup.invoice_orders!([ @first, @second ])
    perform_enqueued_jobs
    invoice = group.invoice

    group.cancel!

    assert invoice.reload.canceled?
    assert_nil @first.reload.order_group_id
    assert_nil @second.reload.order_group_id
    assert @first.pending?
    assert @second.pending?
    assert_nil @first.invoice

    again = Shop::OrderGroup.invoice_orders!([ @first, @second ], send_email: false)

    assert_not_equal group.id, again.id
    assert_equal "2024-04", again.period
    assert again.invoice
    assert_equal 2, again.orders.count
  end

  test "a late order for an already invoiced period gets its own invoice" do
    travel_to "2024-05-01"
    Shop::OrderGroup.invoice_due!(send_email: false)
    assert @first.reload.invoiced?
    assert @second.reload.invoiced?

    late = create_shop_order(delivery: deliveries(:monday_2))
    Shop::OrderGroup.invoice_due!(send_email: false)

    assert late.reload.invoiced?
    assert_not_equal @first.order_group_id, late.order_group_id
    assert_equal "2024-04", late.order_group.period
    assert_equal [ late.id ], late.order_group.orders.pluck(:id)
  end

  test "does not invoice a period that has not ended" do
    travel_to "2024-04-30"

    assert_no_difference -> { Invoice.count } do
      Shop::OrderGroup.invoice_due!(send_email: false)
    end
    assert @first.reload.pending?
  end

  test "refuses orders that do not share a member and a period" do
    other = create_shop_order(member: members(:john), delivery: deliveries(:thursday_1))

    assert_raises(ArgumentError) do
      Shop::OrderGroup.invoice_orders!([ @first, other ])
    end
  end

  test "index totals count the group invoice, not a missing order invoice" do
    Shop::OrderGroup.invoice_orders!([ @first, @second ], send_email: false)
    perform_enqueued_jobs
    @first.invoice.update_columns(paid_amount: 4)

    totals = Shop::Order.effective_invoice_totals(Shop::Order.where(id: [ @first.id, @second.id ]))
    one = Shop::Order.effective_invoice_totals(Shop::Order.where(id: @first.id))

    assert_equal 4, totals[:paid]
    assert_in_delta @first.invoice.amount - 4, totals[:missing], 0.001
    assert_equal @first.amount + @second.amount, totals[:amount]
    share = @first.amount / @first.invoice.amount
    assert_in_delta 4 * share, one[:paid], 0.001
    assert_in_delta (@first.invoice.amount - 4) * share, one[:missing], 0.001
    assert_equal @first.amount, one[:amount]
  end

  test "display period is the calendar span, not an order id" do
    group = Shop::OrderGroup.create!(member: members(:jane), period: "2024-04")
    assert_equal "Orders April 2024", group.display_period

    group.update!(period: "2026-Q3")
    assert_equal "Orders 3rd quarter 2026", group.display_period

    I18n.with_locale(:fr) do
      assert_equal "Commandes 3e trimestre 2026", group.display_period
    end
    I18n.with_locale(:de) do
      assert_equal "Bestellungen 3. Quartal 2026", group.display_period
    end
    I18n.with_locale(:it) do
      assert_equal "Ordini 3° trimestre 2026", group.display_period
    end
    I18n.with_locale(:nl) do
      assert_equal "Bestellingen 3e kwartaal 2026", group.display_period
    end
  end

  test "period phrase names the month, quarter, or year" do
    group = Shop::OrderGroup.create!(member: members(:jane), period: "2026-01")

    assert_equal "for the month of January 2026", group.period_phrase
    I18n.with_locale(:fr) do
      assert_equal "du mois de janvier 2026", group.period_phrase
      group.period = "2026-04"
      assert_equal "du mois d'avril 2026", group.period_phrase
      group.period = "2026-08"
      assert_equal "du mois d'août 2026", group.period_phrase
      group.period = "2026-10"
      assert_equal "du mois d'octobre 2026", group.period_phrase
    end
    I18n.with_locale(:de) do
      group.period = "2026-01"
      assert_equal "des Monats Januar 2026", group.period_phrase
    end
    I18n.with_locale(:it) do
      assert_equal "del mese di gennaio 2026", group.period_phrase
    end
    I18n.with_locale(:nl) do
      assert_equal "van de maand januari 2026", group.period_phrase
    end

    group.period = "2026-Q3"
    assert_equal "for the 3rd quarter of 2026", group.period_phrase
    I18n.with_locale(:fr) { assert_equal "du 3e trimestre 2026", group.period_phrase }
    I18n.with_locale(:de) { assert_equal "des 3. Quartals 2026", group.period_phrase }
    I18n.with_locale(:it) { assert_equal "del 3° trimestre 2026", group.period_phrase }
    I18n.with_locale(:nl) { assert_equal "van het 3e kwartaal 2026", group.period_phrase }

    group.period = "2026"
    assert_equal "for the year 2026", group.period_phrase
    I18n.with_locale(:fr) { assert_equal "de l'année 2026", group.period_phrase }
    I18n.with_locale(:de) { assert_equal "des Jahres 2026", group.period_phrase }
    I18n.with_locale(:it) { assert_equal "dell'anno 2026", group.period_phrase }
    I18n.with_locale(:nl) { assert_equal "van het jaar 2026", group.period_phrase }
  end
end
