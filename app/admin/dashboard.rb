# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  DEPOTS_LIMIT = 12

  menu priority: 1, label: -> {
    icon "home", title: t("active_admin.dashboard"), class: "w-5 h-5 my-0.5 min-w-6"
  }

  content title: proc { onboarding? ? "" : t("active_admin.dashboard") } do
    if onboarding?
      render "onboarding"
    else
      next_delivery = Delivery.next
      columns do
        column do
          if next_delivery
            date_format = next_delivery.fiscal_year == Current.fiscal_year ? :long_no_year : :long
            panel t(".next_delivery", delivery: link_to(next_delivery.display_name(format: date_format), next_delivery)).html_safe, action: next_delivery_panel_action(next_delivery) do
              counts = next_delivery.basket_counts
              if counts.present?
                render partial: "active_admin/deliveries/baskets",
                  locals: { delivery: next_delivery, scope: :active }

                if next_delivery.note?
                  para class: "mt-4 p-2 text-sm rounded-md bg-green-200 dark:bg-green-900" do
                    next_delivery.note
                  end
                end

                if Current.org.feature?("absence")
                  absences_count = next_delivery.baskets.absent.sum(:quantity)
                  if absences_count.positive?
                    div class: "text-right mt-2 p-2" do
                      link_to t(".absences_count", count: absences_count), absences_path(q: { including_date: next_delivery.date.to_s })
                    end
                  end
                end
              else
                div class: "missing-data" do
                  if feature?("shop")
                    t(".no_baskets_or_shop_orders")
                  else
                    t(".no_baskets")
                  end
                end
              end
            end
          else
            panel t(".no_next_delivery") do
              link_to t(".no_next_deliveries"), deliveries_path, class: "missing-data"
            end
          end
        end

        column do
          panel Member.model_name.human(count: 2) do
            render "members_count"
          end

          panel Membership.model_name.human(count: 2) do
            render "memberships_count"
          end

          if Current.org.feature?("activity")
            panel activities_human_name do
              render "activity_participations_count"
            end
          end

          panel t(".billing"), action: billing_panel_action do
            div class: "px-2" do
              table class: "w-full text-base data-table-invoice-total" do
                tbody do
                  InvoiceTotal.all(Current.fiscal_year).each do |total|
                    tr class: "px-2 h-10 border-dotted border-b border-gray-200 dark:border-gray-700" do
                      td total.title
                      td class: "text-right tabular-nums w-36" do
                        cur(total.price)
                      end
                    end
                  end
                end
              end
            end

            div class: "px-2" do
              h4 Payment.model_name.human(count: 2), class: "text-base font-semibold mt-4"
              table class: "p-2 w-full text-base data-table-total" do
                tbody do
                  PaymentTotal.all.each do |total|
                    tr class: "h-10 border-dotted border-b border-gray-200 dark:border-gray-700" do
                      td total.title
                      td class: "text-right tabular-nums w-36" do
                       cur(total.price)
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
