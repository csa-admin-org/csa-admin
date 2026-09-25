# frozen_string_literal: true

module DeliveriesHelper
  def delivery_fiscal_year_frame(date, bulk: nil)
    date = delivery_fiscal_year_date(date)
    confirm = delivery_create_confirm(date)
    bulk_confirm = delivery_bulk_create_confirm(bulk)
    year = date && Current.org.fiscal_year_for(date).to_s

    turbo_frame_tag(
      "delivery-fiscal-year",
      data: { delivery_fiscal_year_target: "frame" }) do
      tag.span(
        (t("active_admin.resources.delivery.fiscal_year_of_date", year: year) if year),
        class: "delivery-fiscal-year",
        data: {
          delivery_fiscal_year_target: "payload",
          confirm: confirm.to_s,
          for_date: date&.iso8601.to_s,
          bulk_confirm: bulk_confirm.to_s,
          bulk_for: delivery_bulk_key(bulk)
        })
    end
  end

  def delivery_bulk_preview(params)
    delivery = Delivery.new
    delivery.bulk_dates_starts_on = params[:bulk_dates_starts_on]
    delivery.bulk_dates_ends_on = params[:bulk_dates_ends_on]
    delivery.bulk_dates_weeks_frequency = params[:bulk_dates_weeks_frequency]
    delivery.bulk_dates_wdays = Array(params[:bulk_dates_wdays])
    delivery
  end

  def delivery_create_confirm(date)
    return if date.blank?
    return unless Current.org.fiscal_year_for(date).year == Current.fy_year

    delivery_confirm_text("create_confirm", Delivery.memberships_receiving_basket_count(date))
  end

  def delivery_bulk_create_confirm(delivery)
    return if delivery.blank? || delivery.date?

    starts = delivery.bulk_dates_starts_on
    return if starts.blank?
    return unless Current.org.fiscal_year_for(starts).year == Current.fy_year

    dates = delivery.bulk_dates
    return if dates.blank?

    delivery_confirm_text(
      "create_confirm_bulk",
      Delivery.memberships_receiving_basket_count_for(dates))
  end

  def delivery_bulk_key(delivery)
    return "" if delivery.blank?

    [
      delivery.bulk_dates_starts_on,
      delivery.bulk_dates_ends_on,
      delivery.bulk_dates_weeks_frequency,
      Array(delivery.bulk_dates_wdays).map(&:to_i).sort.join("-")
    ].join("|")
  end

  private

  def delivery_confirm_text(key, count)
    return if count.to_i.zero?

    t("active_admin.resources.delivery.#{key}",
      count: count,
      basket: Basket.model_name.human.downcase,
      memberships: Membership.model_name.human(count: count).downcase)
  end

  def delivery_fiscal_year_date(date)
    case date
    when Date then date
    when String
      Date.iso8601(date)
    end
  rescue Date::Error
    nil
  end
end
