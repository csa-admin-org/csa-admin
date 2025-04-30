# frozen_string_literal: true

module DashboardHelper
  def onboarding?
    return false if Tenant.custom?

    Delivery.none? || Depot.kept.none? ||
      (Current.org.member_form_mode == "membership" && BasketSize.kept.none?)
  end

  def next_delivery_panel_action(delivery)
    icon_file_link(:csv, baskets_path(q: { delivery_id_eq: delivery.id }, format: :csv), title: Delivery.human_attribute_name(:summary)) +
      icon_file_link(:xlsx, delivery_path(delivery, format: :xlsx), title: Delivery.human_attribute_name(:summary)) +
      icon_file_link(:pdf, delivery_path(delivery, format: :pdf), target: "_blank", title: Delivery.human_attribute_name(:sheets))
  end

  def billing_panel_action
    latest_snapshots = Billing::Snapshot.order(created_at: :desc).first(4)
    content_tag :div, class: "flex items-center space-x-3" do
      (
        if latest_snapshots.any?
          content_tag(:div) {
            content_tag :button, id: "billing-snapshots-button", class: "flex items-center size-6 justify-center", data: { "dropdown-toggle" => "billing-snapshots-menu", "dropdown-offset-distance" => "1", "dropdown-placement" => "bottom-end" } do
              icon "chevron-down", class: "size-6"
            end
          } + content_tag(:div, id: "billing-snapshots-menu", class: "z-50 hidden min-w-max bg-white rounded-sm shadow-lg ring-1 ring-black/5 focus:outline-hidden dark:bg-gray-700 py-2 px-2 text-right text-sm text-gray-700 dark:text-gray-200", "aria-labelledby" => "user-menu-button") do
            content_tag(:div, class: "block mb-2") {
              t(".quarterly_snapshots")
            } + content_tag(:ul, class: "space-y-1") do
              latest_snapshots.map do |s|
                content_tag :li, class: "p2" do
                  link_to l(s.created_at.to_date, format: :number), billing_snapshot_path(s), data: { turbo: false }
                end
              end.join.html_safe
            end
          end
        end || "".html_safe
      ) + icon_file_link(:xlsx, billing_path(Current.fy_year, format: :xlsx), title: Invoice.human_attribute_name(:summary))
    end
  end
end
