# frozen_string_literal: true

module Demo::Seeder::Contents
  extend ActiveSupport::Concern

  private

  def seed_absences!
    log "Seeding absences..."
    seed_fiscal_years.each do |fy|
      memberships = Membership.during_year(fy).to_a
      next if memberships.size < Demo::Seeder::ABSENCES_PER_YEAR

      memberships.sample(Demo::Seeder::ABSENCES_PER_YEAR).each do |membership|
        create_absence_for!(membership, fy)
      end
    end
  end

  def create_absence_for!(membership, fy)
    deliveries = membership.deliveries.order(:date).select { |delivery| fy.range.cover?(delivery.date) }
    return if deliveries.size < 3

    start_index = rand(0...(deliveries.size - 3))
    end_index = [ start_index + rand(1..2), deliveries.size - 1 ].min
    Absence.create!(
      member: membership.member,
      started_on: deliveries[start_index].date,
      ended_on: deliveries[end_index].date,
      admin: true)
  end

  def seed_basket_contents!
    log "Seeding basket contents..."
    deliveries = seed_deliveries_for_contents
    return if @products.blank? || deliveries.blank?

    deliveries_with_baskets = deliveries.select { |delivery| delivery.baskets.active.any? }
    return if deliveries_with_baskets.empty?

    basket_sizes = BasketSize.paid.reorder(:id)
    return if basket_sizes.empty?

    deliveries_to_fill(deliveries_with_baskets).uniq(&:id).each do |delivery|
      fill_basket_content!(delivery, basket_sizes)
    end
  end

  def seed_deliveries_for_contents
    if @deliveries_by_year.present?
      @deliveries_by_year.values.flatten
    else
      Array(@current_year_deliveries)
    end
  end

  def deliveries_to_fill(deliveries_with_baskets)
    eligible_for_coverage = deliveries_with_baskets.select { |delivery| delivery.date <= 1.week.from_now }
    filled = eligible_for_coverage.group_by { |delivery|
      Analytics.year_for(delivery.date)
    }.flat_map { |year, year_deliveries|
      rate = Demo::Seeder::CONTENTS_COVERAGE_BY_OFFSET.fetch(fy_offset_for_year(year), 0.90)
      fill_count = [ (year_deliveries.size * rate).ceil, 1 ].max
      year_deliveries.sort_by(&:date).first(fill_count)
    }
    filled.concat(basket_content_deliveries_to_always_fill(deliveries_with_baskets))
  end

  def basket_content_deliveries_to_always_fill(candidates)
    last_past = candidates.select { |delivery| delivery.date <= Date.current }.max_by(&:date)
    upcoming = candidates.select { |delivery| delivery.date > Date.current }.min_by(&:date)
    [ last_past, upcoming ].compact
  end

  def fill_basket_content!(delivery, basket_sizes)
    total_price = basket_sizes.sum(&:price)
    @products.sample(6).each do |product|
      BasketContent.create!(
        delivery: delivery,
        product: product,
        unit_price: product.default_price,
        depot_ids: @all_depots.map(&:id),
        basket_size_ids_quantities: basket_content_quantities(product, basket_sizes, total_price))
    end
  end

  def basket_content_quantities(product, basket_sizes, total_price)
    base_qty = product.unit == "kg" ? rand(1700..2000) : rand(9..12)
    quantities = basket_sizes.each_with_object({}) do |bs, hash|
      qty = (base_qty * bs.price / total_price.to_f).round
      hash[bs.id.to_s] = qty if qty > 0
    end
    return quantities if quantities.any?

    largest = basket_sizes.max_by(&:price)
    { largest.id.to_s => [ base_qty, 1 ].max }
  end
end
