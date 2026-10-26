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

  # Prebuilt option HTML, not a collection. Rails only treats a select as
  # grouped when its first choice is a group, so a flat declined option ahead
  # of the groups would render each group as a single empty option.
  def basket_shift_form_collection(basket)
    selected = basket.shift_target_basket_id
    declined = if basket.absence_id?
      options_for_select([ [ t("active_admin.resource.form.basket_shift_declined"), :declined ] ], selected)
    end
    safe_join([ declined, grouped_options_for_select(basket_admin_shift_targets_collection(basket), selected) ])
  end

  def basket_shift_panel_text(basket)
    key = basket.absence_id? ? "basket_shift_explanation" : "basket_shift_one_step"
    t("active_admin.resource.form.#{key}")
  end

  def basket_shift_target_hint(basket)
    hint = t("formtastic.hints.basket.shift_target_basket_id")
    return hint unless basket.admin_off_cycle_shift_deliveries.any?

    "#{hint} #{t("active_admin.resource.form.off_cycle_date")}"
  end

  def basket_admin_shift_targets_collection(source)
    options = source.membership.baskets.includes(:delivery, :baskets_basket_complements).filter_map { |target|
      next if target.delivery_id == source.delivery_id

      [
        target.delivery.date,
        [
          admin_shift_delivery_label(target.delivery),
          target.id,
          disabled: !source.admin_shift_target?(target)
        ]
      ]
    } + source.admin_off_cycle_shift_deliveries.map { |delivery|
      [
        delivery.date,
        [ "#{admin_shift_delivery_label(delivery)} *", "delivery:#{delivery.id}" ]
      ]
    }

    basket_shift_target_groups(
      source,
      options,
      after: "active_admin.resource.form.following_deliveries",
      before: "active_admin.resource.form.previous_deliveries")
  end

  # Plain text: a <select> option cannot hold markup, and Safari's menu drops
  # the label entirely when the option contains nested elements.
  def admin_shift_delivery_label(delivery)
    "#{l(delivery.date, format: :medium)} #{delivery.display_number}"
  end

  def basket_shift_targets_member_collection(source)
    options = source.member_shiftable_basket_targets.map { |target|
      [ target.delivery.date, [ l(target.delivery.date, format: :long_no_year).capitalize, target.id ] ]
    } + source.member_off_cycle_shift_deliveries.map { |delivery|
      label = "#{l(delivery.date, format: :long_no_year).capitalize} *"
      [ delivery.date, [ label, "delivery:#{delivery.id}" ] ]
    }

    basket_shift_target_groups(
      source,
      options,
      after: ".after_absence",
      before: ".before_absence")
  end

  def basket_shift_target_groups(source, options, after:, before:)
    date = source.delivery.date
    grouped = options.sort_by(&:first).group_by { |option_date,| option_date < date ? :before : :after }
    [
      [ t(before), grouped[:before]&.map(&:last) || [] ],
      [ t(after), grouped[:after]&.map(&:last) || [] ]
    ].select { |_, group_options| group_options.any? }
  end
end
