# frozen_string_literal: true

require "rounding"

class MembershipPricing
  def initialize(params = {}, promotion: nil)
    # Works with both the registration and renewal form params
    @params = params.transform_keys { |k|
      k.to_s
        .sub(/\Awaiting_/, "")
        .sub(/members_basket_complements_attributes/, "memberships_basket_complements_attributes")
    }.with_indifferent_access
    @promotion = promotion
    @min = 0
    @max = 0
  end

  def prices
    @prices ||= begin
      add(baskets_prices)
      add(baskets_price_extras)
      add(depot_prices)
      add(delivery_cycle_prices)
      complements_prices.each { |prices| add(prices) }
      add(activity_participations_prices)
      subtract_price_reduction
      subtract_promotion

      [ @min, @max ].uniq
    end
  end

  def present?
    return false if simple_pricing?
    return true if @promotion_applied

    prices.any?(&:positive?)
  end

  private

  def simple_pricing?
    Depot.visible.sum(:price).zero?
      && BasketComplement.visible.sum(:price).zero?
      && DeliveryCycle.visible.map(&:billable_deliveries_count).uniq.one?
      && DeliveryCycle.visible.sum(:price).zero?
      && deliveries_counts.one?
      && !Current.org.feature?("basket_price_extra")
      && !@params[:activity_participations_demanded_annually]
      && quoted_price_reduction.nil?
      && @promotion.nil?
  end

  def basket_size
    @basket_size ||= BasketSize.find_by(id: @params[:basket_size_id])
  end

  def baskets_prices
    return [ 0, 0 ] unless basket_size

    [
      deliveries_counts.min * basket_size.price,
      deliveries_counts.max * basket_size.price
    ]
  end

  def baskets_price_extras
    extra = @params[:basket_price_extra].to_f
    return [ 0, 0 ] if extra.zero? || !basket_size || delivery_cycles.empty?

    totals = delivery_cycles.filter_map { |cycle| extra_total_for(cycle, extra) }
    return [ 0, 0 ] if totals.empty?

    [ totals.min, totals.max ]
  end

  def extra_total_for(delivery_cycle, extra)
    count = delivery_cycle.billable_deliveries_count_for_basket_size(basket_size)
    return unless count.positive?

    count * Current.org.calculate_basket_price_extra(
      extra,
      basket_size.price,
      basket_size.id,
      complements_annual_price(delivery_cycle) / count,
      count,
      delivery_cycle: delivery_cycle,
      basket_size: basket_size)
  end

  def complements_annual_price(delivery_cycle)
    attrs = @params[:memberships_basket_complements_attributes].to_h
    return 0 if attrs.blank?

    attrs.sum { |_, row|
      complement = BasketComplement.find_by(id: row[:basket_complement_id])
      quantity = row[:quantity].to_i
      next 0 unless complement && quantity.positive?

      (delivery_cycle.billable_deliveries_count_for_basket_complement(complement) *
        complement.price * quantity).round_to_five_cents
    }
  end

  def complements_prices
    attrs = @params[:memberships_basket_complements_attributes].to_h
    return [ [ 0, 0 ] ] unless attrs.present?

    attrs.map { |_, attrs|
      complement_prices(attrs[:basket_complement_id], attrs[:quantity].to_i)
    }
  end

  def complement_prices(complement_id, quantity)
    complement = BasketComplement.find_by(id: complement_id)
    return [ 0, 0 ] unless complement
    return [ 0, 0 ] if quantity.zero?
    return [ 0, 0 ] unless delivery_cycles.any?

    deliveries_counts = delivery_cycles.map { |dc|
      dc.billable_deliveries_count_for_basket_complement(complement)
    }.uniq
    return [ 0, 0 ] if deliveries_counts.empty? || deliveries_counts.any?(&:nil?)

    [
      deliveries_counts.min * complement.price * quantity,
      deliveries_counts.max * complement.price * quantity
    ]
  end

  def activity_participations_prices
    return [ 0, 0 ] unless @params[:activity_participations_demanded_annually]
    return [ 0, 0 ] unless basket_size
    return [ 0, 0 ] unless delivery_cycles.any?

    fy = Delivery.last&.fiscal_year
    return [ 0, 0 ] unless fy

    counts = delivery_cycles.map { |dc|
      m = Membership.new(
        started_on: fy.beginning_of_year,
        ended_on: fy.end_of_year,
        member: Member.new(salary_basket: false),
        basket_size: basket_size,
        delivery_cycle: dc,
        memberships_basket_complements_attributes: @params[:memberships_basket_complements_attributes].to_h,
        activity_participations_annual_price_change: nil)
      m.activity_participations_demanded_annually = m.activity_participations_demanded_annually_by_default
      default = ActivityParticipationDemanded.new(m).count
      m.activity_participations_demanded_annually = @params[:activity_participations_demanded_annually]
      demanded = ActivityParticipationDemanded.new(m).count
      -1 * (demanded - default)  * Current.org.activity_price
    }
    return [ 0, 0 ] if counts.empty? || counts.any?(&:nil?)

    [ counts.min, counts.max ]
  end

  def depot_prices
    return [ 0, 0 ] unless depot

    [
      deliveries_counts.min * depot.price,
      deliveries_counts.max * depot.price
    ]
  end

  def delivery_cycle_prices
    return [ 0, 0 ] unless delivery_cycle

    [
      deliveries_counts.min * delivery_cycle.price,
      deliveries_counts.max * delivery_cycle.price
    ]
  end

  def deliveries_counts
    return [ 0 ] unless delivery_cycles.any?

    @deliveries_counts ||= begin
      if basket_size
        delivery_cycles.map { |dc|
          dc.billable_deliveries_count_for_basket_size(basket_size)
        }.flatten.uniq.sort
      else
        delivery_cycles.map(&:billable_deliveries_count).flatten.uniq.sort
      end
    end
  end

  def delivery_cycles
    return [ delivery_cycle ] if delivery_cycle

    @delivery_cycle_ids ||= depots.map(&:delivery_cycle_ids).flatten.uniq
    @delivery_cycles ||= DeliveryCycle.find(@delivery_cycle_ids).to_a
  end

  def delivery_cycle
    @delivery_cycle ||=
      DeliveryCycle.find_by(id: @params[:delivery_cycle_id])
  end

  def depots
    return [ depot ] if depot

    @depots ||= Depot.visible.includes(:delivery_cycles).to_a
  end

  def depot
    @depot ||= Depot.find_by(id: @params[:depot_id])
  end

  # Registration starts on the next delivery of the chosen cycle. Renewal quotes
  # the following membership year, passed in by the renewal form.
  def quoted_fiscal_year
    @quoted_fiscal_year ||=
      if (year = @params[:renewal_fiscal_year].presence)
        Current.org.fiscal_year_for(year.to_i)
      else
        (delivery_cycle&.next_delivery || Delivery.next)&.fiscal_year || Current.fiscal_year
      end
  end

  def quoted_price_reduction
    return unless Current.org.feature?("price_reductions")

    id = @params[:price_reduction_id].presence || @params[:selected_price_reduction_id]
    @quoted_price_reduction ||= PriceReduction.visible.kept.find_by(id: id)
  end

  # The selected program is quoted before its card is complete. A date that
  # is already past the quote date is not: that cut will not be granted.
  def subtract_price_reduction
    reduction = quoted_price_reduction
    return unless reduction
    return unless reduction.depot_allowed?(depot)
    return if quoted_card_expired?(reduction)

    cuts = [ @min, @max ].map { |gross| reduction.raw_amount(gross) }
    return if reduction.capped? && cuts.max > reduction.remaining_amount(quoted_fiscal_year.year).to_d

    @min -= cuts.min
    @max -= cuts.max
  end

  # After the price reduction, same cap as a claim: the discount cannot
  # take the quoted amount below zero.
  def subtract_promotion
    return unless @promotion

    cuts = [ @min, @max ].map { |gross| [ @promotion.amount.to_d, gross ].min }
    return unless cuts.any?(&:positive?)

    @promotion_applied = true
    @min = [ @min - cuts.min, 0 ].max
    @max = [ @max - cuts.max, 0 ].max
  end

  def quoted_card_expired?(reduction)
    type = reduction.price_reduction_card
    return false unless type&.require_expires_on?

    row = quoted_card_rows.find { |card|
      card[:price_reduction_card_id].to_s == type.id.to_s
    }
    expires_on = row && row[:expires_on].presence
    return false unless expires_on

    Date.parse(expires_on.to_s) < quoted_on
  rescue Date::Error, TypeError
    false
  end

  # Registration quotes the next delivery. Renewal quotes the following year.
  def quoted_on
    if @params[:renewal_fiscal_year].present?
      quoted_fiscal_year.beginning_of_year
    else
      (delivery_cycle&.next_delivery || Delivery.next)&.date || Date.current
    end
  end

  # The registration form posts [] rows. A hash keyed by index is the other shape.
  def quoted_card_rows
    cards = @params[:member_cards_attributes]
    return [] if cards.blank?

    rows = cards.is_a?(Array) ? cards : cards.values
    Array(rows).filter_map { |row|
      next unless row.respond_to?(:[])

      row.respond_to?(:with_indifferent_access) ? row.with_indifferent_access : row
    }
  end

  def add(prices)
    @min, @max =
      [ @min, @max ].zip(rounded_prices(prices)).map(&:sum)
  end

  def rounded_prices(prices)
    Array(prices).map { |price| (price || 0).round_to_five_cents }
  end
end
