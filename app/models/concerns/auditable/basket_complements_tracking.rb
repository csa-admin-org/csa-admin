# frozen_string_literal: true

module Auditable::BasketComplementsTracking
  private

  def track_basket_complements_change(name, association)
    instance_variable_set(tracked_basket_complements_variable_name(name), association.map(&:attributes))
  end

  def basket_complements_change(name, association)
    before_attributes = instance_variable_get(tracked_basket_complements_variable_name(name))
    return unless before_attributes

    before_all = serialize_basket_complements(before_attributes)
    after_all = serialize_basket_complements(association.reject(&:marked_for_destruction?).map(&:attributes))
    return if before_all == after_all

    changed_basket_complements(before_all, after_all)
  end

  def changed_basket_complements(before_all, after_all)
    before_by_id = before_all.index_by { |c| c["id"] }
    after_by_id = after_all.index_by { |c| c["id"] }

    before_changed = []
    after_changed = []
    (before_by_id.keys | after_by_id.keys).sort_by(&:to_i).each do |id|
      before_complement = before_by_id[id]
      after_complement = after_by_id[id]
      next if before_complement == after_complement

      before_changed << before_complement if before_complement
      after_changed << after_complement if after_complement
    end

    [ before_changed, after_changed ]
  end

  def serialize_basket_complements(complements_attributes)
    complements_attributes
      .reject { |attrs| attrs["_destroy"] == "1" || attrs["_destroy"] == true }
      .sort_by { |attrs| attrs["id"].to_i }
      .map { |attrs|
        {
          "id" => attrs["id"],
          "basket_complement_id" => attrs["basket_complement_id"],
          "quantity" => attrs["quantity"],
          "price" => attrs["price"]&.to_f,
          "delivery_cycle_id" => attrs["delivery_cycle_id"]
        }.compact
      }
  end

  def tracked_basket_complements_variable_name(name)
    :"@tracked_#{name}_attributes"
  end
end
