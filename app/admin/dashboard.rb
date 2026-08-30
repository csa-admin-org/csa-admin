# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: -> {
    [
      icon("house", title: t("active_admin.dashboard"), class: "admin-nav-icon"),
      content_tag(:span, t("active_admin.dashboard"), class: "admin-nav-label")
    ].join.html_safe
  }

  content title: proc { onboarding? ? "" : t("active_admin.dashboard") } do
    if Tenant.demo? && params[:welcome] != "false"
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
            panel t(".next_delivery", delivery: link_to(next_delivery.display_name(format: date_format), next_delivery)).html_safe, icon: "calendar", action: next_delivery_panel_action(next_delivery) do
              counts = next_delivery.basket_counts
              complement_counts = next_delivery.basket_complement_counts
              if counts.present? || complement_counts.present?
                render partial: "active_admin/deliveries/baskets",
                  locals: {
                    delivery: next_delivery,
                    scope: :active,
                    counts: counts,
                    complement_counts: complement_counts
                  }

                if next_delivery.note?
                  para class: "delivery-note" do
                    next_delivery.note
                  end
                end

                bottom_links = []
                announcements_count = Announcement.active.deliveries_eq(next_delivery.id).count
                if announcements_count.positive?
                  bottom_links << link_to(t(".announcements_count", count: announcements_count), announcements_path(scope: :active, q: { deliveries_eq: next_delivery.id }))
                end
                if bottom_links.present?
                  div class: "dashboard-links" do
                    bottom_links.join(content_tag(:span, "/", class: "is-faint link-sep")).html_safe
                  end
                end

                div class: "dashboard-section" do
                  render partial: "active_admin/deliveries/absences", locals: { delivery: next_delivery }
                  render partial: "active_admin/deliveries/changes", locals: { delivery: next_delivery }
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
            panel t(".no_next_delivery"), icon: "calendar" do
              link_to t(".no_next_deliveries"), deliveries_path, class: "missing-data"
            end
          end
        end

        column do
          week = requested_calendar_monday
          calendar = Calendar.new(week || Date.current)
          turbo_frame id: "dashboard_calendar", target: "_top" do
            if week || calendar.present?
              panel t(".calendar"), icon: "calendar-days", action: calendar_panel_action(calendar) do
                render partial: "active_admin/page/calendar", locals: { calendar: calendar }
              end
            end
          end

          panel Member.model_name.human(count: 2), icon: "users" do
            render "members_count"
          end

          panel Membership.model_name.human(count: 2), icon: "calendar-range" do
            render "memberships_count"
          end

          if feature?("bidding_round") && open_bidding_round
            panel link_to(open_bidding_round.title, open_bidding_round), icon: "scale" do
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
            panel activities_human_name, icon: "handshake" do
              render "activity_participations_count"
            end
          end

          panel t(".billing"), icon: "banknotes", action: billing_panel_action do
            div class: "dashboard-panel-body" do
              table class: "is-full text-base data-table-invoice-total" do
                tbody do
                  invoice_totals = InvoiceTotal.all(Current.fiscal_year)
                  invoice_totals.each_with_index do |total, i|
                    is_total = i == invoice_totals.size - 1
                    tr class: "dotted-row" do
                      td total.title
                      td class: "text-right tabular-nums col-num" do
                        previsional_details(self, total.price, total.try(:previsional_amounts_by_month), unit: is_total)
                      end
                    end
                  end
                end
              end
            end

            div class: "dashboard-panel-body dashboard-section" do
              h4 Payment.model_name.human(count: 2), class: "text-base font-semibold"
              table class: "is-full text-base data-table-total" do
                tbody do
                  payment_totals = PaymentTotal.all(Current.fiscal_year)
                  payment_totals.each_with_index do |total, i|
                    is_total = i == payment_totals.size - 1
                    tr class: "dotted-row" do
                      td total.title
                      td class: "text-right tabular-nums col-num" do
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
