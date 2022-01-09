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
              span do
                link_to Invoice.human_attribute_name(:xlsx_recap), billing_path(Current.fy_year, format: :xlsx)
              end
              latest_snapshots = Billing::Snapshot.order(updated_at: :desc).first(4)
              if latest_snapshots.any?
                span "<br/><br/>".html_safe
                span do
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
              table_for counts.all do
                column Depot.model_name.human, :title
                column Basket.model_name.human, :count, class: 'align-right'
                column "#{next_delivery.basket_sizes.map { |bs| bs.name&.gsub(/\s/, '&nbsp;') }.join(' /&nbsp;')}".html_safe, :baskets_count, class: 'align-right'
              end

              paid_depots = next_delivery.depots.paid
              if paid_depots.any?
                free_counts = BasketCounts.new(next_delivery, Depot.free.pluck(:id))
                paid_counts = BasketCounts.new(next_delivery, Depot.paid.pluck(:id))
                totals = [
                  OpenStruct.new(
                    title: "#{Basket.model_name.human(count: 2)}: #{free_counts.depots.pluck(:name).to_sentence}",
                    count: free_counts.sum,
                    baskets_count: free_counts.sum_detail),
                  OpenStruct.new(
                    title: t('.baskets_to_prepare'),
                    count:  paid_counts.sum,
                    baskets_count: paid_counts.sum_detail)
                ]
                table_for totals do
                  column nil, :title
                  column nil, :count, class: 'align-right'
                  column nil, :baskets_count, class: 'align-right'
                end
              end

              table_for nil do
                column(nil, :title) { t('.totals', numbers: '') }
                column(class: 'align-right') { counts.sum }
                column(class: 'align-right') { counts.sum_detail }
              end

              if BasketComplement.any?
                counts = BasketComplementCount.all(next_delivery)
                div id: 'basket-complements-table' do
                  if counts.any?
                    table_for counts do
                      column BasketComplement.model_name.human, :title
                      if Current.acp.feature_flag?('shop')
                        column Membership.model_name.human(count: 2), :memberships_count, class: 'align-right'
                        column Shop::Order.model_name.human(count: 2), :shop_orders_count, class: 'align-right'
                      end
                      column t('.total', number: ''), :count, class: 'align-right'
                    end
                  else
                    em t('.no_basket_complements')
                  end
                end
              end

              if Current.acp.feature_flag?('shop')
                count = Shop::Order.all_without_cart.where(delivery: next_delivery).count
                div id: 'shop-orders' do
                  span do
                    span(class: 'bold') { t('shop.title') + ": " }
                    span do
                      link_to t('shop.orders', count: count), shop_orders_path(q: { delivery_id_eq: next_delivery.id }, scope: :all_without_cart)
                    end
                  end
                end
              end

              table_for nil do
                column do
                  span do
                    link_to Delivery.human_attribute_name(:xlsx_recap), delivery_path(next_delivery, format: :xlsx)
                  end
                  span { '&nbsp;/&nbsp;'.html_safe }
                  span do
                    link_to Delivery.human_attribute_name(:signature_sheets), delivery_path(next_delivery, format: :pdf)
                  end

                  if Current.acp.feature?('absence')
                    absences_count = next_delivery.baskets.absent.sum(:quantity)
                    if absences_count.positive?
                      span class: 'delivery_absences' do
                        link_to "#{Absence.model_name.human(count: absences_count)}: #{absences_count}", absences_path(q: { including_date: next_delivery.date.to_s })
                      end
                    end
                  end
                end
              end
            end

            if authorized?(:update, Delivery)
              span class: 'delivery_note' do
                form_for next_delivery do |f|
                  f.text_area :note
                  f.submit t('.submit_delivery_note')
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
