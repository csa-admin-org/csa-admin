# frozen_string_literal: true

require "test_helper"

class Membership::PricingTest < ActiveSupport::TestCase
  test "price from association" do
    travel_to "2024-01-01"
    delivery_cycles(:thursdays).update!(price: 2)
    membership = create_membership(
      basket_size: basket_sizes(:medium),
      depot: depots(:bakery),
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 },
        "1" => { basket_complement_id: eggs_id, quantity: 1 }
      })

    assert_equal 10 * 20, membership.basket_sizes_price
    assert_equal 10 * 4, membership.depots_price
    assert_equal 10 * (4 + 6), membership.basket_complements_price
    assert_equal 10 * 2, membership.deliveries_price
    assert_equal 0, membership.activity_participations_annual_price_change
    assert_equal 360, membership.price
  end

  test "price from association with non-billable baskets" do
    travel_to "2024-01-01"
    delivery_cycles(:thursdays).update!(
      price: 2,
      absences_included_annually: 2)
    membership = create_membership(
      basket_size: basket_sizes(:medium),
      depot: depots(:bakery),
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 },
        "1" => { basket_complement_id: eggs_id, quantity: 1 }
      })

    assert_equal 8 * 20, membership.basket_sizes_price
    assert_equal 8 * 4, membership.depots_price
    assert_equal 8 * (4 + 6), membership.basket_complements_price
    assert_equal 8 * 2, membership.deliveries_price
    assert_equal 0, membership.activity_participations_annual_price_change
    assert_equal 288, membership.price
  end

  test "price with custom prices and quantity" do
    travel_to "2024-01-01"
    membership = create_membership(
      basket_size: basket_sizes(:medium),
      basket_size_price: 21,
      basket_quantity: 2,
      depot: depots(:bakery),
      depot_price: 3,
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, price: "3.5", quantity: 3 },
        "1" => { basket_complement_id: eggs_id, price: "6.1", quantity: 2 }
      }
    )

    assert_equal 20 * 21, membership.basket_sizes_price
    assert_equal 20 * 3, membership.depots_price
    assert_equal 10 * (3 * 3.5 + 2 * 6.1), membership.basket_complements_price
    assert_equal 0, membership.deliveries_price
    assert_equal 0, membership.activity_participations_annual_price_change
    assert_equal 707, membership.price
  end

  test "price with 3-digit precision depot price" do
    travel_to "2024-01-01"
    depots(:bakery).update!(price: 1.125)
    membership = create_membership(
      basket_size: basket_sizes(:small),
      depot: depots(:bakery),
      delivery_cycle: delivery_cycles(:thursdays))

    assert_equal 10 * 10, membership.basket_sizes_price
    assert_equal 10 * 1.125, membership.depots_price
    assert_equal 111.25, membership.price
  end

  test "with baskets_annual_price_change price" do
    travel_to "2024-01-01"
    membership = create_membership(
      baskets_annual_price_change: -11)

    assert_equal(-11, membership.baskets_annual_price_change)
    assert_equal 100 - 11, membership.price
  end

  test "with custom basket dynamic extra price" do
    travel_to "2024-01-01"
    membership = create_membership(
      basket_price_extra: 3)

    assert_equal 10 * 3, membership.baskets_price_extra
    assert_equal 130, membership.price
  end

  test "with basket complement with deliveries cycle" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:thursdays)
    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :odd }
      ]
    )
    membership = create_membership(
      delivery_cycle: delivery_cycles(:all),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1, delivery_cycle: delivery_cycles(:thursdays) }
      }
    )

    assert_equal 20 * 10, membership.basket_sizes_price
    assert_equal 5 * 4, membership.basket_complements_price
    assert_equal 220, membership.price
  end

  test "with basket_complements_annual_price_change price" do
    travel_to "2024-01-01"
    membership = create_membership(
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      },
      basket_complements_annual_price_change: -10
    )

    assert_equal 10 * 10, membership.basket_sizes_price
    assert_equal 10 * 4, membership.basket_complements_price
    assert_equal(-10, membership.basket_complements_annual_price_change)
    assert_equal 130, membership.price
  end

  test "with activity_participations_annual_price_change price" do
    travel_to "2024-01-01"
    membership = create_membership(
      activity_participations_annual_price_change: -90)

    assert_equal(-90, membership.activity_participations_annual_price_change)
    assert_equal 10, membership.price
  end

  test "salary basket prices" do
    travel_to "2024-01-01"
    members(:john).update!(salary_basket: true)
    membership = memberships(:john)

    assert_equal 0, membership.basket_sizes_price
    assert_equal 0, membership.basket_complements_price
    assert_equal 0, membership.depots_price
    assert_equal 0, membership.activity_participations_annual_price_change
    assert_equal 0, membership.price
  end

  test "#cancel_overcharged_invoice! membership period is reduced" do
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)
    membership.update!(billing_year_division: 1)

    travel_to "2024-05-01"
    Current.reset # clear memoized fiscal_year after travel_to
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs
    membership.reload.update!(ended_on: "2024-05-15")

    assert_difference -> { membership.reload.invoices_amount }, -invoice.amount do
      membership.cancel_overcharged_invoice!
      perform_enqueued_jobs
    end
    assert_equal "canceled", invoice.reload.state
  end

  test "#cancel_overcharged_invoice! only cancel the over-paid invoices" do
    member = members(:jane)
    membership = memberships(:jane)

    travel_to "2024-01-01"
    invoice_1 = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    travel_to "2024-04-01"
    invoice_2 = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    travel_to "2024-07-01"
    invoice_3 = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    membership.update!(baskets_annual_price_change: -250)

    assert_difference -> { membership.reload.invoices_amount }, -invoice_2.amount - invoice_3.amount do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "canceled", invoice_2.reload.state
    assert_equal "canceled", invoice_3.reload.state
    assert_equal "open", invoice_1.reload.state
  end

  test "#cancel_overcharged_invoice! membership basket size price is reduced" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)

    membership.update!(billing_year_division: 1)
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs
    membership.baskets.first.update!(basket_size_price: 29)

    assert_difference -> { membership.reload.invoices_amount }, -invoice.amount do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "canceled", invoice.reload.state
  end

  test "#cancel_overcharged_invoice! new absent basket not billed are updated" do
    travel_to "2024-01-01"
    org(absences_billed: false)
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)

    membership.update!(billing_year_division: 1)
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    last_basket = membership.baskets.last
    assert_difference -> { membership.baskets.billable.count }, -1 do
      create_absence(
        member: member,
        started_on: last_basket.delivery.date - 1.day,
        ended_on: last_basket.delivery.date + 1.day)
    end
    assert_not last_basket.reload.billable

    assert_difference -> { membership.reload.invoices_amount }, -invoice.amount do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "canceled", invoice.reload.state
  end

  test "#cancel_overcharged_invoice! past membership period is not reduced" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)

    membership.update!(billing_year_division: 1)
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    travel_to "2025-01-01"
    Current.reset # clear memoized fiscal_year after travel_to
    membership.baskets.first.update!(basket_size_price: 29)

    assert_no_difference -> { membership.reload.invoices_amount } do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "open", invoice.reload.state
  end

  test "#cancel_overcharged_invoice! basket complement is added with extra price difference" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)

    membership.update!(billing_year_division: 1)
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    membership.reload
    membership.update!(memberships_basket_complements_attributes: {
      "1" => { basket_complement_id: eggs_id, quantity: 1 }
    })

    assert_no_difference -> { membership.reload.invoices_amount } do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "open", invoice.reload.state
  end

  test "destroying membership cancels or destroys its invoices" do
    org(billing_year_divisions: [ 12 ])
    mail_templates(:invoice_created)
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = memberships(:jane)
    membership.update_column(:billing_year_division, 12)

    travel_to "2024-01-01"
    sent_invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs
    travel_to "2024-02-01"
    not_sent_invoice = force_invoice(member, send_email: false)
    perform_enqueued_jobs

    travel_to "2024-03-01"
    assert_difference -> { Invoice.not_canceled.reload.count }, -2 do
      membership.destroy
    end
    assert_equal "canceled", sent_invoice.reload.state
    assert_raises(ActiveRecord::RecordNotFound) { not_sent_invoice.reload }
  end
end
