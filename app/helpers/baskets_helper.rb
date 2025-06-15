# frozen_string_literal: true

module BasketsHelper
  def display_basket_state(basket)
    if basket.trial?
      content_tag(:span, t("active_admin.status_tag.trial"), class: "status-tag", data: { status: "trial" })
    elsif basket.absent?
      if basket.absence
        link_to basket.absence do
          content_tag(:span, t("active_admin.status_tag.absent"), class: "status-tag", data: { status: "absent" })
        end
      else
        content_tag(:span, t("active_admin.status_tag.absent") + " *", class: "status-tag italic", data: { status: "absent" })
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
    admin_basket_complements.map do |complement|
      [ complement.name, complement.id,
        disabled: complement.current_and_future_delivery_ids.exclude?(basket.delivery_id),
        data: {
          delivery_ids: complement.current_and_future_delivery_ids.join(",")
        } ]
    end
  end

  def basket_shift_targets_collection(source)
    col = [
      [ t(".basket_shift_none"), [ [ t(".basket_shift_declined"), :declined ] ] ],
      [ t(".following_deliveries"), basket_shifts_targets_collection_for(source, (source.delivery.date + 1.day)..) ],
      [ t(".previous_deliveries"), basket_shifts_targets_collection_for(source, ...source.delivery.date) ]
    ]
  end

  def basket_shifts_targets_collection_for(source, range)
    source.membership.baskets.between(range).includes(:delivery).map { |target|
      [ target.delivery.display_name, target.id, disabled: !BasketShift.shiftable?(source, target) ]
    }
  end

  def basket_shift_targets_member_collection(source)
    col = [ [ t(".basket_shift_none"), [ [ t(".basket_shift_declined"), :declined ] ] ] ]

    before_targets = basket_shifts_targets_member_collection_for(source, ...source.delivery.date)
    if before_targets.any?
      col << [ t(".before_absence"), before_targets ]
    end

    after_targets = basket_shifts_targets_member_collection_for(source, (source.delivery.date + 1.day)..)
    if after_targets.any?
      col << [ t(".after_absence"), after_targets ]
    end

    col.to_h
  end

  def basket_shifts_targets_member_collection_for(source, range)
    source
      .member_shiftable_basket_targets
      .select { |target| target.delivery.date.in?(range) }
      .map { |target|
        [ l(target.delivery.date, format: :long_no_year).capitalize, target.id ]
      }
  end
end
