# frozen_string_literal: true

module DashboardHelper
  def onboarding?
    return false if Tenant.custom?

    Delivery.none?
      || Depot.kept.none?
      || (Current.org.member_form_mode == "membership" && BasketSize.kept.none?)
  end

  def requested_calendar_monday
    return if params[:week].blank?

    monday = parse_iso_week(params[:week].to_s)
    return unless monday

    mondays = Calendar.busy_mondays
    mondays ? monday.clamp(mondays.begin, mondays.end) : monday
  end

  def calendar_day_path(day)
    return unless day.busy?

    if day.delivery?
      delivery_path(day.delivery)
    elsif day.special_delivery
      shop_special_delivery_path(day.special_delivery)
    else
      calendar_activity_participations_path(day)
    end
  end

  def calendar_activity_participations_path(day)
    activity_participations_path(
      scope: :all,
      q: {
        activity_date_gteq: day.date,
        activity_date_lteq: day.date
      })
  end

  def calendar_panel_action(calendar)
    content_tag(:div, class: "calendar-nav") {
      content_tag(:span, calendar_range_label(calendar), class: "calendar-nav-range tabular-nums") +
      calendar_nav_control(
        calendar.prev_start_on && calendar_week_path(calendar.prev_start_on),
        icon: "chevron-left",
        label: t("active_admin.previous")) +
      calendar_nav_control(
        calendar.default? ? nil : root_path,
        icon: "circle-small",
        label: t("active_admin.page.index.current_week")) +
      calendar_nav_control(
        calendar.next_start_on && calendar_week_path(calendar.next_start_on),
        icon: "chevron-right",
        label: t("active_admin.next"))
    }
  end

  def calendar_nav_control(url, icon:, label:)
    inner = content_tag(:span, label, class: "sr-only") +
      content_tag(:span) { icon(icon, class: "icon-5") }
    if url
      link_to url,
        class: "calendar-nav-control",
        title: label,
        data: { turbo_frame: "dashboard_calendar", turbo_action: "advance" } do
        inner
      end
    else
      content_tag(:span, class: "calendar-nav-control is-disabled", title: label) do
        inner
      end
    end
  end

  def calendar_range_label(calendar)
    first = calendar.days.first.date
    last = calendar.days.last.date
    if first.year == last.year
      "#{l(first, format: :short_no_year)}–#{l(last, format: :short_no_year)}"
    else
      "#{l(first, format: :short)}–#{l(last, format: :short)}"
    end
  end

  def calendar_week_path(monday)
    root_path(week: monday.strftime("%G-W%V"))
  end

  def parse_iso_week(value)
    year, week = value.match(/\A(\d{4})-W(\d{2})\z/)&.captures
    return unless year && week

    Date.commercial(year.to_i, week.to_i, 1)
  rescue ArgumentError
    nil
  end

  def next_delivery_panel_action(delivery)
    icon_file_links(
      icon_file_link(:csv, baskets_path(q: { delivery_id_eq: delivery.id }, format: :csv), title: Delivery.human_attribute_name(:summary)),
      icon_file_link(:xlsx, delivery_path(delivery, format: :xlsx), title: Delivery.human_attribute_name(:summary)),
      icon_file_link(:pdf, delivery_path(delivery, format: :pdf), title: Delivery.human_attribute_name(:sheets), target: "_blank"))
  end

  def billing_panel_action
    latest_snapshots = Billing::Snapshot.order(created_at: :desc).first(4)
    snapshots =
      if latest_snapshots.any?
        content_tag(:div, class: "admin-billing-snapshots", data: { controller: "tooltip", "tooltip-dismissible-value" => true, "tooltip-placement-value" => "bottom-end" }) {
          content_tag(:button,
            type: "button",
            id: "billing-snapshots-button",
            class: "admin-billing-snapshots-trigger",
            data: {
              "tooltip-target" => "trigger",
              action: "click->tooltip#toggle"
            },
            aria: {
              controls: "billing-snapshots-menu",
              expanded: false
            }
          ) do
            icon "chevron-down", class: "admin-billing-snapshots-icon"
          end +
          content_tag(:div,
            id: "billing-snapshots-menu",
            class: "admin-menu is-padded",
            data: { "tooltip-target" => "content" }
          ) do
            content_tag(:div, class: "admin-billing-snapshots-title") {
              t(".quarterly_snapshots")
            } + content_tag(:ul, class: "admin-billing-snapshots-list") do
              latest_snapshots.map do |s|
                content_tag :li, class: "tabular-nums" do
                  link_to l(s.created_at.to_date, format: :number), billing_snapshot_path(s), data: { turbo: false }
                end
              end.join.html_safe
            end
          end
        }
      else
        "".html_safe
      end

    snapshots + icon_file_link(:xlsx, billing_path(Current.fy_year, format: :xlsx), title: Invoice.human_attribute_name(:summary))
  end
end
