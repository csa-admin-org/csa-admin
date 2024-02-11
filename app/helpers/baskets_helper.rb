module BasketsHelper
  def display_basket_state(basket)
    if basket.trial?
      content_tag(:span, t("active_admin.status_tag.trial"), class: "status_tag trial")
    elsif basket.absent?
      if basket.absence
        link_to basket.absence do
          content_tag(:span, t("active_admin.status_tag.absent"), class: "status_tag absent")
        end
      else
        content_tag(:span, t("active_admin.status_tag.absent"), class: "status_tag absent")
      end
    end
  end

  def basket_deliveries_collection(basket)
    membership = basket.membership
    unused_deliveries =
      Delivery
        .between(membership.period)
        .where.not(id: (membership.deliveries.pluck(:id) - [ basket.delivery_id ]))
    unused_deliveries.map do |delivery|
      [ delivery.display_name(format: :long), delivery.id ]
    end
  end

  def basket_complements_collection(basket)
    BasketComplement.all.map do |complement|
      [ complement.name, complement.id,
        disabled: complement.current_and_future_delivery_ids.exclude?(basket.delivery_id),
        data: {
          delivery_ids: complement.current_and_future_delivery_ids.join(",")
        } ]
    end
  end
end
