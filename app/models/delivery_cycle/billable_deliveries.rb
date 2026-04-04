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

    def deliveries_counts_for(object)
      aggregate_counts_for(:deliveries_count, object)
    end

    def absences_included_counts_for(object)
      aggregate_counts_for(:absences_included_count, object)
    end

    # Pro-rate included absences removal
    def billable_deliveries_counts_for(object)
      aggregate_counts_for(:billable_deliveries_count, object)
    end

    def future_deliveries_counts
      if visible?
        visible.map(&:future_deliveries_count).uniq.sort
      else
        [ primary.future_deliveries_count ]
      end
    end

    private

    def aggregate_counts_for(method_prefix, object)
      type = object.class.model_name.singular
      method_name = :"#{method_prefix}_for_#{type}"
      if visible?
        visible.map { |dc| dc.public_send(method_name, object) }.uniq.sort
      else
        [ primary.public_send(method_name, object) ]
      end
    end
  end

  def billable_deliveries_count
    deliveries_count - absences_included_annually
  end

  def deliveries_count_for_basket_complement(basket_complement)
    (basket_complement.delivery_ids & current_and_future_delivery_ids).size
  end

  def billable_deliveries_count_for_basket_complement(basket_complement)
    deliveries_count_for_basket_complement(basket_complement) - absences_included_count_for_basket_complement(basket_complement)
  end

  def absences_included_count_for_basket_complement(basket_complement)
    return 0 unless absences_included_annually.positive?
    full_year = deliveries_count.to_f
    return 0 unless full_year.positive?
    (deliveries_count_for_basket_complement(basket_complement) / full_year * absences_included_annually).round
  end

  def deliveries_count_for_basket_size(basket_size)
    return deliveries_count if basket_size.always_deliverable?

    source_deliveries = future_deliveries.any? ? future_deliveries : current_deliveries
    basket_size.filter_deliveries(source_deliveries).size
  end

  def billable_deliveries_count_for_basket_size(basket_size)
    [ deliveries_count_for_basket_size(basket_size) - absences_included_count_for_basket_size(basket_size), 0 ].max
  end

  def absences_included_count_for_basket_size(basket_size)
    return absences_included_annually if basket_size.always_deliverable?
    return 0 unless absences_included_annually.positive?
    full_year = deliveries_count.to_f
    return 0 unless full_year.positive?
    (deliveries_count_for_basket_size(basket_size) / full_year * absences_included_annually).round
  end
end
