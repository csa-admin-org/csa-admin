# frozen_string_literal: true

class MembershipBasketsUpdater::Overrides
  def initialize(membership, range)
    @membership = membership
    @range = range
  end

  def desired_deliveries(scheduled_deliveries)
    deliveries = scheduled_deliveries.index_by(&:id)
    deliveries.except!(*source_delivery_ids_in_range)
    target_deliveries_in_range.each { |delivery| deliveries[delivery.id] = delivery }
    deliveries.values.sort_by(&:date)
  end

  def conflicts
    @conflicts ||= {
      missing_targets: target_delivery_ids - target_deliveries.keys,
      duplicate_targets: target_delivery_ids.tally.select { |_, count| count > 1 }.keys
    }.compact_blank
  end

  def reapply!(created_delivery_ids)
    created_delivery_ids = created_delivery_ids.to_set
    reapply_delivery_swaps!(created_delivery_ids)
    reapply_regular_overrides!(created_delivery_ids)
  end

  private

  def basket_overrides
    @basket_overrides ||= @membership.basket_overrides.includes(:delivery).to_a
  end

  def delivery_swap_overrides
    @delivery_swap_overrides ||= basket_overrides.select(&:delivery_swap?)
  end

  def relevant_delivery_swap_overrides
    @relevant_delivery_swap_overrides ||= delivery_swap_overrides.select { |override|
      target = target_deliveries[target_delivery_id(override)]
      @range.cover?(override.delivery.date) || (target && @range.cover?(target.date))
    }
  end

  def regular_basket_overrides
    @regular_basket_overrides ||= basket_overrides.reject(&:delivery_swap?)
  end

  def source_delivery_ids_in_range
    relevant_delivery_swap_overrides.filter_map { |override|
      override.delivery_id if @range.cover?(override.delivery.date)
    }
  end

  def target_deliveries_in_range
    target_deliveries.values.select { |delivery| @range.cover?(delivery.date) }
  end

  def target_deliveries
    @target_deliveries ||= Delivery.where(id: all_target_delivery_ids).index_by(&:id)
  end

  def all_target_delivery_ids
    @all_target_delivery_ids ||= delivery_swap_overrides.map { |override| target_delivery_id(override) }
  end

  def target_delivery_ids
    @target_delivery_ids ||= relevant_delivery_swap_overrides.map { |override| target_delivery_id(override) }
  end

  def target_delivery_id(override)
    override.diff["override_delivery_id"].to_i
  end

  def reapply_delivery_swaps!(created_delivery_ids)
    relevant_delivery_swap_overrides.each do |override|
      target_id = target_delivery_id(override)
      override.apply_to!(basket_at(target_id)) if created_delivery_ids.include?(target_id)
    end
  end

  def reapply_regular_overrides!(created_delivery_ids)
    regular_basket_overrides.each do |override|
      override.apply_to!(basket_at(override.delivery_id)) if created_delivery_ids.include?(override.delivery_id)
    end
  end

  def basket_at(delivery_id)
    @membership.baskets.find_by!(delivery_id: delivery_id)
  end
end
