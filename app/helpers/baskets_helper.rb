# frozen_string_literal: true

module BasketsHelper
  def absences_included_usage(membership)
    used = membership.absences_included_used
    absences = link_to absences_path(
      q: { member_id_eq: membership.member_id, during_year: membership.fy_year },
      scope: :all) do
      t("active_admin.resource.show.absences_used",
        count: used,
        limit: membership.absences_included)
    end
    return absences if membership.force_absences_included_annually?

    prorated = link_to handbook_page_path("absence", anchor: "absence-included-logic") do
      t("active_admin.resource.show.absences_prorated_from",
        count: membership.absences_included_annually)
    end
    safe_join([ absences, " ", prorated ])
  end

  def basket_absent_quantity_wrapper(basket)
    return {} unless basket.absent? && !basket.can_only_be_shifted?

    {
      data: {
        controller: "form-absent-quantity",
        form_absent_quantity_message_value: t("active_admin.resource.form.absent_quantity_confirm")
      }
    }
  end

  def basket_row_struck?(basket)
    !basket.billable? || basket.empty?
  end

  def display_basket_state(basket)
    if basket.trial?
      content_tag(:span, t("active_admin.status_tag.trial"), class: "status-tag", data: { status: "trial" })
    elsif basket.forced?
      content_tag(:span, t("active_admin.status_tag.forced"), class: "status-tag", data: { status: "forced" })
    elsif basket.absent?
      if basket.absence
        link_to basket.absence do
          content_tag(:span, t("active_admin.status_tag.absent"), class: "status-tag", data: { status: "absent" })
        end
      else
        content_tag(:span, t("active_admin.status_tag.absent") + " *", class: "status-tag is-italic", data: { status: "absent" })
      end
    end
  end

  def basket_complements_collection(basket)
    admin_basket_complements.map do |complement|
      [ complement.name, complement.id,
        disabled: complement.current_and_future_delivery_ids.exclude?(basket.delivery_id),
        data: {
          delivery_ids: complement.current_and_future_delivery_ids.join(","),
          price: catalog_price_placeholder(complement.price)
        } ]
    end
  end

  def basket_panel_count(membership)
    delivered = membership.baskets.billable.where("baskets.quantity > 0")
    baskets = delivered.sum(:quantity)
    deliveries = delivered.distinct.count(:delivery_id)
    return baskets if baskets == deliveries

    [ baskets, deliveries ]
  end

  def basket_shift_form_collection(basket)
    col = basket.absence_id? ? [ [ t("active_admin.resource.form.basket_shift_declined"), :declined ] ] : []
    col + basket_admin_shift_targets_collection(basket)
  end

  def basket_shift_panel_text(basket)
    key = basket.absence_id? ? "basket_shift_explanation" : "basket_shift_one_step"
    t("active_admin.resource.form.#{key}")
  end

  def basket_admin_shift_targets_collection(source)
    (
      source.membership.baskets.includes(:delivery, :baskets_basket_complements).filter_map { |target|
        next if target.delivery_id == source.delivery_id

        [ target.delivery.date, [
          target.delivery.display_name,
          target.id,
          disabled: !source.admin_shift_target?(target)
        ] ]
      } + source.admin_off_cycle_shift_deliveries.map { |delivery|
        [ delivery.date, [ delivery.display_name, "delivery:#{delivery.id}" ] ]
      }
    ).sort_by(&:first).map(&:last)
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

    other_dates = basket_shift_off_cycle_member_collection(source)
    if other_dates.any?
      col << [ t(".other_dates"), other_dates ]
    end

    col.to_h
  end

  def basket_shift_off_cycle_member_collection(source)
    source.member_off_cycle_shift_deliveries.map { |delivery|
      [ l(delivery.date, format: :long_no_year).capitalize, "delivery:#{delivery.id}" ]
    }
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
