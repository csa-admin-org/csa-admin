# frozen_string_literal: true

module DashboardHelper
  def onboarding?
    return false if Tenant.custom?

    Delivery.none?
      || Depot.kept.none?
      || (Current.org.member_form_mode == "membership" && BasketSize.kept.none?)
  end

  def next_delivery_panel_action(delivery)
    content_tag(:div, class: "flex items-center gap-2") do
      icon_file_link(:csv, baskets_path(q: { delivery_id_eq: delivery.id }, format: :csv), title: Delivery.human_attribute_name(:summary)) +
        icon_file_link(:xlsx, delivery_path(delivery, format: :xlsx), title: Delivery.human_attribute_name(:summary)) +
        icon_file_link(:pdf, delivery_path(delivery, format: :pdf), title: Delivery.human_attribute_name(:sheets), target: "_blank")
    end
  end

  def billing_panel_action
    latest_snapshots = Billing::Snapshot.order(created_at: :desc).first(4)
    content_tag :div, class: "flex items-center space-x-3" do
      (
        if latest_snapshots.any?
          content_tag(:div, class: "relative", data: { controller: "tooltip", "tooltip-dismissible-value" => true, "tooltip-placement-value" => "bottom-end" }) {
            content_tag(:button,
              type: "button",
              id: "billing-snapshots-button",
              class: "flex cursor-pointer items-center justify-center hover:bg-gray-100 dark:hover:bg-gray-800 rounded",
              data: {
                "tooltip-target" => "trigger",
                action: "click->tooltip#toggle"
              },
              aria: {
                controls: "billing-snapshots-menu",
                expanded: false
              }
            ) do
              icon "chevron-down", class: "size-7"
            end +
            content_tag(:div,
              id: "billing-snapshots-menu",
              class: "invisible fixed z-50 min-w-max rounded-sm bg-white px-2 py-2 text-right text-sm text-gray-700 opacity-0 shadow-lg ring-1 ring-black/5 transition-opacity duration-150 focus:outline-hidden dark:bg-gray-800 dark:text-gray-200",
              data: { "tooltip-target" => "content" }
            ) do
              content_tag(:div, class: "block mb-2") {
                t(".quarterly_snapshots")
              } + content_tag(:ul, class: "space-y-1") do
                latest_snapshots.map do |s|
                  content_tag :li, class: "p2 tabular-nums" do
                    link_to l(s.created_at.to_date, format: :number), billing_snapshot_path(s), data: { turbo: false }
                  end
                end.join.html_safe
              end
            end
          }
        end || "".html_safe
      ) + icon_file_link(:xlsx, billing_path(Current.fy_year, format: :xlsx), title: Invoice.human_attribute_name(:summary))
    end
  end
end
