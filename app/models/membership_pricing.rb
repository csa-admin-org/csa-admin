require "rounding"

class MembershipPricing
  def initialize(params = {})
    @params = params
    @min = 0
    @max = 0
  end

  def prices
    @prices ||= begin
      add(baskets_prices)
      add(baskets_price_extras)
      add(depot_prices)
      complements_prices.each { |prices| add(prices) }

      [ @min, @max ].uniq
    end
  end

  def present?
    !simple_pricing? && prices.any?(&:positive?)
  end

  private

  def simple_pricing?
    Depot.visible.sum(:price).zero? &&
      BasketComplement.visible.sum(:price).zero? &&
      DeliveryCycle.visible.map(&:billable_deliveries_count).uniq.one? &&
      deliveries_counts.one? &&
      !Current.acp.feature?("basket_price_extra")
  end

  def basket_size
    @basket_size ||= BasketSize.find_by(id: @params[:waiting_basket_size_id])
  end

  def baskets_prices
    return [ 0, 0 ] unless basket_size

    [
      deliveries_counts.min * basket_size.price,
      deliveries_counts.max * basket_size.price
    ]
  end

  def baskets_price_extras
    extra = @params[:waiting_basket_price_extra].to_f
    return [ 0, 0 ] if extra.zero?

    comp_prices = [ 0, 0 ]
    complements_prices.each { |p|
      comp_prices = comp_prices.zip(p.map(&:round_to_five_cents)).map(&:sum)
    }

    [
      deliveries_counts.min * calculate_price_extra(extra, basket_size, comp_prices.min / deliveries_counts.min, deliveries_counts.min),
      deliveries_counts.max * calculate_price_extra(extra, basket_size, comp_prices.max / deliveries_counts.max, deliveries_counts.max)
    ]
  end

  def calculate_price_extra(extra, basket_size, complements_price, deliveries_count)
    return 0 unless Current.acp.feature?("basket_price_extra")
    return 0 unless basket_size

    Current.acp.calculate_basket_price_extra(
      extra,
      basket_size.price,
      basket_size.id,
      complements_price,
      deliveries_count)
  end

  def complements_prices
    attrs = @params[:members_basket_complements_attributes].to_h
    return [ [ 0, 0 ] ] unless attrs.present?

    attrs.map { |_, attrs|
      complement_prices(attrs[:basket_complement_id], attrs[:quantity].to_i)
    }
  end

  def complement_prices(complement_id, quantity)
    complement = BasketComplement.find_by(id: complement_id)
    return [ 0, 0 ] unless complement
    return [ 0, 0 ] if quantity.zero?

    deliveries_counts = delivery_cycles.map { |dc|
      dc.billable_deliveries_count_for(complement)
    }.uniq
    [
      deliveries_counts.min * complement.price * quantity,
      deliveries_counts.max * complement.price * quantity
    ]
  end

  def depot_prices
    return [ 0, 0 ] unless depot

    [
      deliveries_counts.min * depot.price,
      deliveries_counts.max * depot.price
    ]
  end

  def deliveries_counts
    return [ 0 ] unless delivery_cycles.any?

    @deliveries_counts ||= delivery_cycles.map(&:billable_deliveries_count).flatten.uniq.sort
  end

  def delivery_cycles
    return [ delivery_cycle ] if delivery_cycle
    return [ basket_size.delivery_cycle ] if basket_size&.delivery_cycle

    @delivery_cycle_ids ||= depots.map(&:delivery_cycle_ids).flatten.uniq
    @delivery_cycles ||= DeliveryCycle.find(@delivery_cycle_ids).to_a
  end

  def delivery_cycle
    @delivery_cycle ||=
      DeliveryCycle.find_by(id: @params[:waiting_delivery_cycle_id])
  end

  def depots
    return [ depot ] if depot

    @depots ||= Depot.visible.includes(:delivery_cycles).to_a
  end

  def depot
    @depot ||= Depot.find_by(id: @params[:waiting_depot_id])
  end

  def add(prices)
    @min, @max =
      [ @min, @max ].zip(prices.map(&:round_to_five_cents)).map(&:sum)
  end
end
