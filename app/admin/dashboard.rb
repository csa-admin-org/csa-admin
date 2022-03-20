ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: -> {
    inline_svg_tag('admin/home.svg', size: '20', title: I18n.t('active_admin.dashboard'))
  }

  content title: proc { I18n.t('active_admin.dashboard').html_safe } do
    next_delivery = Delivery.next
    columns do
      column do
        panel Member.model_name.human(count: 2) do
          table_for members_count, i18n: Member do
            column :status
            column :count, class: 'align-right'
          end
        end

        panel t('.billing_year', fiscal_year: Current.fiscal_year) do
          table_for InvoiceTotal.all, class: 'totals_2' do
            column Invoice.model_name.human(count: 2), :title
            column(class: 'align-right') { |total| cur(total.price) }
          end

          table_for PaymentTotal.all, class: 'totals' do
            column Payment.model_name.human(count: 2), :title
            column(class: 'align-right') { |total| cur(total.price) }
          end

          table_for nil do
            column do
              div style: 'margin-top: 15px' do
                link_to_with_icon :xlsx_file, Invoice.human_attribute_name(:summary), billing_path(Current.fy_year, format: :xlsx)
              end
              latest_snapshots = Billing::Snapshot.order(updated_at: :desc).first(4)
              if latest_snapshots.any?
                div style: 'margin-top: 15px' do
                  txt = t('.quarterly_snapshots')
                  txt += ': '
                  txt += latest_snapshots.map { |s|
                      link_to l(s.updated_at.to_date, format: :number), billing_snapshot_path(s)
                    }.join(' / ')
                  txt.html_safe
                end
              end
            end
          end
        end
      end

      column do
        if next_delivery
          panel t('.next_delivery', delivery: link_to(next_delivery.display_name(format: :long), next_delivery)).html_safe do
            counts = next_delivery.basket_counts
            if counts.present?
              render partial: 'active_admin/deliveries/baskets', locals: { delivery: next_delivery }

              if Current.acp.feature?('shop')
                count = Shop::Order.all_without_cart.where(delivery: next_delivery).count
                div id: 'shop-orders' do
                  span(class: 'bold') { t('shop.title') + ':' }
                  span(style: 'margin-left: 5px') do
                    link_to t('shop.orders', count: count), shop_orders_path(q: { delivery_id_eq: next_delivery.id }, scope: :all_without_cart)
                  end
                end
              end

              if next_delivery.note?
                div class: 'delivery-note' do
                  para next_delivery.note
                end
              end

              div class: 'next-delivery-footer' do
                table_for nil do
                  column do
                    span do
                      span style: 'display: inline-block; margin-right: 20px' do
                        link_to_with_icon :xlsx_file, Delivery.human_attribute_name(:summary), delivery_path(next_delivery, format: :xlsx)
                      end
                      span style: 'display: inline-block;' do
                        link_to_with_icon :pdf_file, Delivery.human_attribute_name(:signature_sheets), delivery_path(next_delivery, format: :pdf), target: '_blank'
                      end
                    end

                    if Current.acp.feature?('absence')
                      absences_count = next_delivery.baskets.absent.sum(:quantity)
                      if absences_count.positive?
                        span class: 'delivery_absences' do
                          link_to t('.absences_count', count: absences_count), absences_path(q: { including_date: next_delivery.date.to_s })
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        else
          panel t('.no_next_delivery') do
            div class: 'blank_slate_container' do
              i do
                link_to t('.no_next_deliveries'), deliveries_path
              end
            end
          end
        end

        if Current.acp.feature?('group_buying')
          if next_group_buying_delivery = GroupBuying::Delivery.next
            panel t('.next_group_buying_delivery', delivery: link_to(next_group_buying_delivery.display_name, next_group_buying_delivery)).html_safe do
              table_for GroupBuying::OrderTotal.all(next_group_buying_delivery), class: 'totals', i18n: GroupBuying::Order do
                column :state, :title
                column(GroupBuying::Order.model_name.human(count: 2), class: 'align-right') { |total| total.count }
                column(class: 'align-right') { |total| cur(total.price) }
              end
            end
          else
            panel t('.no_next_group_buying_delivery') do
              div class: 'blank_slate_container' do
                i do
                  link_to t('.no_next_deliveries'), group_buying_deliveries_path
                end
              end
            end
          end
        end

        if Current.acp.feature?('activity')
          panel "#{activities_human_name} #{Current.fy_year}" do
            table_for ActivityParticipationCount.all(Current.fy_year), i18n: ActivityParticipationCount do
              column(:state) { |count| link_to_if(count.url, count.title, count.url) }
              column :count, class: 'align-right'
            end
          end
        end
      end
    end
  end
end
