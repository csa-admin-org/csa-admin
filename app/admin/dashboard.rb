# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: -> {
    [
      icon("home", title: t("active_admin.dashboard"), class: "size-5 md:size-5.5 -mt-1 md:-my-0.5 min-w-5 md:min-w-6 mr-2.5 md:mr-0 inline"),
      content_tag(:span, t("active_admin.dashboard"), class: "inline md:hidden")
    ].join.html_safe
  }

  content title: proc { onboarding? ? "" : t("active_admin.dashboard") } do
    if Tenant.demo?
      info_pane do
        t("active_admin.demo.welcome_html").html_safe
      end
    end

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

                bottom_links = []
                announcements_count = Announcement.active.deliveries_eq(next_delivery.id).count
                if announcements_count.positive?
                  bottom_links << link_to(t(".announcements_count", count: announcements_count), announcements_path(scope: :active, q: { deliveries_eq: next_delivery.id }))
                end
                if bottom_links.present?
                  div class: "text-right mt-2 p-2" do
                    bottom_links.join(content_tag(:span, "/", class: "text-gray-300 dark:text-gray-700 mx-2.5")).html_safe
                  end
                end

                render partial: "active_admin/deliveries/changes", locals: { delivery: next_delivery }
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

          if feature?("bidding_round") && open_bidding_round
            panel link_to(open_bidding_round.title, open_bidding_round) do
              ul class: "counts" do
                li do
                  counter_tag(t("active_admin.resource.show.pledges_percentage").capitalize, open_bidding_round.pledges_percentage, type: :percentage)
                end
                li do
                  counter_tag(t("active_admin.resource.show.total_pledged_percentage").capitalize, open_bidding_round.total_pledged_percentage, type: :percentage)
                end
              end
            end
          end

          if feature?("activity")
            panel activities_human_name do
              render "activity_participations_count"
            end
          end

          panel t(".billing"), action: billing_panel_action do
            div class: "px-2" do
              table class: "w-full text-base data-table-invoice-total" do
                tbody do
                  invoice_totals = InvoiceTotal.all(Current.fiscal_year)
                  invoice_totals.each_with_index do |total, i|
                    is_total = i == invoice_totals.size - 1
                    tr class: "px-2 h-10 border-dotted border-b border-gray-200 dark:border-gray-700" do
                      td total.title
                      td class: "text-right tabular-nums w-36" do
                        previsional_details(self, total.price, total.try(:previsional_amounts_by_month), unit: is_total)
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
                  payment_totals = PaymentTotal.all(Current.fiscal_year)
                  payment_totals.each_with_index do |total, i|
                    is_total = i == payment_totals.size - 1
                    tr class: "h-10 border-dotted border-b border-gray-200 dark:border-gray-700" do
                      td total.title
                      td class: "text-right tabular-nums w-36" do
                       cur(total.price, unit: is_total)
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
