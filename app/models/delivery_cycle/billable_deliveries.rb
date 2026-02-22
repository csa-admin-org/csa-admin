# frozen_string_literal: true

module DeliveryCycle::BillableDeliveries
  extend ActiveSupport::Concern

  class_methods do
    def billable_deliveries_counts
      if visible?
        visible.map(&:billable_deliveries_count).uniq.sort
      else
        [ primary.billable_deliveries_count ]
      end
    end

    def billable_deliveries_count_for(basket_complement)
      if visible?
        visible.map { |dc| dc.billable_deliveries_count_for(basket_complement) }.uniq.sort
      else
        [ primary.billable_deliveries_count_for(basket_complement) ]
      end
    end

    def billable_deliveries_counts_for(basket_size)
      if visible?
        visible.map { |dc| dc.billable_deliveries_count_for_basket_size(basket_size) }.uniq.sort
      else
        [ primary.billable_deliveries_count_for_basket_size(basket_size) ]
      end
    end

    def future_deliveries_counts
      if visible?
        visible.map(&:future_deliveries_count).uniq.sort
      else
        [ primary.future_deliveries_count ]
      end
    end
  end

  def billable_deliveries_count
    deliveries_count - absences_included_annually
  end

  # Pro-rate included absences removal
  def billable_deliveries_count_for(basket_complement)
    count = (basket_complement.delivery_ids & current_and_future_delivery_ids).size
    if absences_included_annually.positive?
      full_year = deliveries_count.to_f
      if full_year.positive?
        count -= (count / full_year * absences_included_annually).round
      end
    end
    count
  end

  def billable_deliveries_count_for_basket_size(basket_size)
    # Use cached count when basket_size has no availability restrictions
    return billable_deliveries_count if basket_size.always_deliverable?

    # Use same logic as deliveries_count: prefer future, fallback to current
    source_deliveries = future_deliveries.any? ? future_deliveries : current_deliveries
    count = basket_size.filter_deliveries(source_deliveries).size
    if absences_included_annually.positive?
      full_year = deliveries_count.to_f
      if full_year.positive?
        count -= (count / full_year * absences_included_annually).round
      end
    end
    [ count, 0 ].max
  end
end
