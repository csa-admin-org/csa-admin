# frozen_string_literal: true

# Handles all pricing calculations and invoice-related logic for memberships.
#
# This concern centralizes the complex pricing calculations that determine
# the total cost of a membership based on basket sizes, depots, delivery
# cycles, complements, and various price adjustments.
#
# Price Components:
#   - basket_sizes_price: Base price for all baskets based on size
#   - baskets_price_extra: Dynamic extra pricing per basket
#   - basket_complements_price: Price for all subscribed complements
#   - depots_price: Delivery depot fees
#   - deliveries_price: Delivery cycle fees
#   - baskets_annual_price_change: Annual adjustment to basket prices
#   - basket_complements_annual_price_change: Annual adjustment to complement prices
#   - activity_participations_annual_price_change: Price adjustment for activity participation
#
module Membership::Pricing
  extend ActiveSupport::Concern

  def billable?
    fy_year >= Current.fy_year
      && (missing_invoices_amount.positive? || overcharged_invoices_amount?)
  end

  def first_billable_delivery
    rel = baskets.filled.billable
    (rel.trial.last || rel.first)&.delivery
  end

  def baskets_annual_price_change=(price)
    super rounded_price(price.to_f)
  end

  def basket_complements_annual_price_change=(price)
    super rounded_price(price.to_f)
  end

  def basket_sizes_price
    rounded_price(
      baskets
        .billable
        .sum("quantity * basket_size_price"))
  end

  def basket_size_total_price(basket_size_id)
    rounded_price(
      baskets
        .billable
        .where(basket_size_id: basket_size_id)
        .sum("quantity * basket_size_price"))
  end

  def baskets_price_extra
    rounded_price(
      baskets
        .billable
        .sum("quantity * calculated_price_extra"))
  end

  def basket_complements_price
    ids = baskets.joins(:baskets_basket_complements).pluck(:basket_complement_id).uniq
    BasketComplement.find(ids).sum { |bc| basket_complement_total_price(bc) }
  end

  def basket_complement_total_price(basket_complement)
    rounded_price(
      baskets
        .billable
        .joins(:baskets_basket_complements)
        .where(baskets_basket_complements: { basket_complement: basket_complement })
        .sum("baskets_basket_complements.quantity * baskets_basket_complements.price"))
  end

  def depots_price
    baskets.pluck(:depot_id).uniq.sum { |id| depot_total_price(id) }
  end

  def depot_total_price(depot_id)
    rounded_price(
      baskets
        .billable
        .where(depot_id: depot_id)
        .sum("quantity * depot_price"))
  end

  # Only billable and filled baskets are considered, only one delivery fee
  # whatever is the quantity
  def deliveries_price
    rounded_price(
      baskets
        .countable
        .sum(&:delivery_cycle_price))
  end

  def missing_invoices_amount
    [ price - invoices_amount, 0 ].max
  end

  def overcharged_invoices_amount?
    invoices.not_canceled.any? && invoices_amount > price
  end

  def cancel_overcharged_invoice!
    return if destroyed?
    return unless current_or_future_year?
    return unless overcharged_invoices_amount?

    invoices.not_canceled.order(:id).last.destroy_or_cancel!
    update_price_and_invoices_amount!
    cancel_overcharged_invoice!
  end

  private

  def update_price_and_invoices_amount!
    computed_price = basket_sizes_price +
      baskets_price_extra +
      baskets_annual_price_change +
      basket_complements_price +
      basket_complements_annual_price_change +
      depots_price +
      deliveries_price +
      activity_participations_annual_price_change
    computed_invoices_amount = invoices.not_canceled.sum(:memberships_amount)

    # Write to in-memory attributes first so PrevisionalInvoicing
    # and Billing::Invoicer read the fresh values directly.
    self[:price] = computed_price
    self[:invoices_amount] = computed_invoices_amount

    update_columns(
      price: computed_price,
      invoices_amount: computed_invoices_amount,
      previsional_invoicing_amounts: Billing::PrevisionalInvoicing.new(self).compute)
  end

  def destroy_or_cancel_invoices!
    invoices.not_canceled.order(id: :desc).each(&:destroy_or_cancel!)
  end

  def rounded_price(price)
    return 0 if member.salary_basket?

    price.round_to_five_cents
  end
end
