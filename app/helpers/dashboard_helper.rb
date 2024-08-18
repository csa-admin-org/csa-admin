# frozen_string_literal: true

module DashboardHelper
  def onboarding?
    Delivery.none? || Depot.kept.none? ||
      (Current.acp.member_form_mode == "membership" && BasketSize.kept.none?)
  end

  def next_delivery_panel_action(delivery)
    icon_link(:csv_file, Delivery.human_attribute_name(:summary), baskets_path(q: { delivery_id_eq: delivery.id }, format: :csv)) +
      icon_link(:xlsx_file, Delivery.human_attribute_name(:summary), delivery_path(delivery, format: :xlsx)) +
      icon_link(:pdf_file, Delivery.human_attribute_name(:sheets), delivery_path(delivery, format: :pdf), target: "_blank")
  end

  def billing_panel_action
    latest_snapshots = Billing::Snapshot.order(created_at: :desc).first(4)
    content_tag :div, class: "flex items-center space-x-3" do
      (
        if latest_snapshots.any?
          content_tag(:div) {
            content_tag :button, id: "billing-snapshots-button", class: "flex items-center w-6 h-6 justify-center", data: { "dropdown-toggle" => "billing-snapshots-menu", "dropdown-offset-distance" => "1", "dropdown-placement" => "bottom-end" } do
              icon "chevron-down", class: "w-6 h-6"
            end
          } + content_tag(:div, id: "billing-snapshots-menu", class: "z-50 hidden min-w-max bg-white rounded shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none dark:bg-gray-700 py-2 px-2 text-right text-sm text-gray-700 dark:text-gray-200", "aria-labelledby" => "user-menu-button") do
            content_tag(:div, class: "block mb-2") {
              t(".quarterly_snapshots")
            } + content_tag(:ul, class: "space-y-1") do
              latest_snapshots.map do |s|
                content_tag :li, class: "p2" do
                  link_to l(s.created_at.to_date, format: :number), billing_snapshot_path(s)
                end
              end.join.html_safe
            end
          end
        end || ""
      ) + icon_link(:xlsx_file, Invoice.human_attribute_name(:summary), billing_path(Current.fy_year, format: :xlsx))
    end
  end
end
