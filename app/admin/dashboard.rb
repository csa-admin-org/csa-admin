ActiveAdmin.register_page "Dashboard" do
  DEPOTS_LIMIT = 12

  menu priority: 1, label: -> {
    inline_svg_tag("admin/home.svg", size: "20", title: t("active_admin.dashboard"))
  }

  content title: proc { t("active_admin.dashboard") unless onboarding? } do
    if onboarding?
      render "onboarding"
    else
      next_delivery = Delivery.next
      columns do
        column do
          panel Member.model_name.human(count: 2) do
            render "members_count"
          end

          panel Membership.model_name.human(count: 2) do
            render "memberships_count"
          end

          if Current.acp.feature?("activity") && Depot.visible.count > DEPOTS_LIMIT
            panel "#{activities_human_name} #{Current.fiscal_year}" do
              render "activity_participations_count"
            end
          end

          panel t(".billing_year", fiscal_year: Current.fiscal_year) do
            div class: "actions" do
              icon_link(:xlsx_file, Invoice.human_attribute_name(:summary), billing_path(Current.fy_year, format: :xlsx))
            end

            table_for InvoiceTotal.all(Current.fiscal_year), class: "totals_2" do
              column Invoice.model_name.human(count: 2), :title
              column(class: "align-right") { |total| cur(total.price) }
            end

            table_for PaymentTotal.all, class: "totals" do
              column Payment.model_name.human(count: 2), :title
              column(class: "align-right") { |total| cur(total.price) }
            end

            latest_snapshots = Billing::Snapshot.order(updated_at: :desc).first(4)
            if latest_snapshots.any?
              div style: "margin: 30px 0 5px 0" do
                txt = t(".quarterly_snapshots")
                txt += ": "
                txt += latest_snapshots.map { |s|
                    link_to l(s.updated_at.to_date, format: :number), billing_snapshot_path(s)
                  }.join(" / ")
                txt.html_safe
              end
            end
          end
        end

        column do
          if next_delivery
            panel t(".next_delivery", delivery: link_to(next_delivery.display_name(format: :long), next_delivery)).html_safe do
              div class: "actions" do
                icon_link(:csv_file, Delivery.human_attribute_name(:summary), baskets_path(q: { delivery_id_eq: next_delivery.id }, format: :csv)) +
                icon_link(:xlsx_file, Delivery.human_attribute_name(:summary), delivery_path(next_delivery, format: :xlsx)) +
                icon_link(:pdf_file, Delivery.human_attribute_name(:sheets), delivery_path(next_delivery, format: :pdf), target: "_blank")
              end

              counts = next_delivery.basket_counts
              if counts.present?
                render partial: "active_admin/deliveries/baskets",
                  locals: { delivery: next_delivery, scope: :not_absent }

                if next_delivery.note?
                  div class: "delivery-note" do
                    para next_delivery.note
                  end
                end

                if Current.acp.feature?("absence")
                  absences_count = next_delivery.baskets.absent.sum(:quantity)
                  if absences_count.positive?
                    div class: "delivery_absences" do
                      link_to t(".absences_count", count: absences_count), absences_path(q: { including_date: next_delivery.date.to_s })
                    end
                  end
                end
              end
            end
          else
            panel t(".no_next_delivery") do
              div class: "blank_slate_container" do
                i do
                  link_to t(".no_next_deliveries"), deliveries_path
                end
              end
            end
          end

          if Current.acp.feature?("activity") && Depot.visible.count <= DEPOTS_LIMIT
            panel "#{activities_human_name} #{Current.fiscal_year}" do
              render "activity_participations_count"
            end
          end
        end
      end
    end
  end
end
