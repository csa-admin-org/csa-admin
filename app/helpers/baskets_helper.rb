module BasketsHelper
  def basket_deliveries_collection(basket)
    membership = basket.membership
    unused_deliveries =
      Delivery
        .between(membership.date_range)
        .where.not(id: (membership.deliveries.pluck(:id) - [basket.delivery_id]))
    unused_deliveries.map do |delivery|
      [delivery.display_name(format: :long), delivery.id]
    end
  end

  def basket_depots_collection(basket)
    Depot.includes(:delivery_cycles).map do |depot|
      [depot.name, depot.id,
        disabled: depot.current_and_future_delivery_ids.exclude?(basket.delivery_id),
        data: {
          delivery_ids: depot.current_and_future_delivery_ids.join(',')
        }]
    end
  end

  def basket_complements_collection(basket)
    BasketComplement.all.map do |complement|
      [complement.name, complement.id,
        disabled: complement.current_and_future_delivery_ids.exclude?(basket.delivery_id),
        data: {
          delivery_ids: complement.current_and_future_delivery_ids.join(',')
        }]
    end
  end
end
