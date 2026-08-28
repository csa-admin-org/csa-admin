# frozen_string_literal: true

module DashboardHelper
  def onboarding?
    return false if Tenant.custom?

    Delivery.none?
      || Depot.kept.none?
      || (Current.org.member_form_mode == "membership" && BasketSize.kept.none?)
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
