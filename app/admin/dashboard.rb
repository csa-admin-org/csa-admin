ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Tableau de bord'

  content title: 'Tableau de bord' do
    next_delivery = Delivery.next
    columns do
      column do
        panel 'Membres' do
          table_for MemberCount.all do
            column('Statut') { |count| link_to count.title, members_path(scope: count.scope) }
            column class: 'align-right' do |count|
              count.count.to_s.prepend(count.count_precision.to_s)
            end
          end
        end

        if feature?('gribouille')
          panel 'Gribouille' do
            if next_delivery
              emails = Member.gribouille_emails
              mail_link = mail_to('', 'mailto', bcc: emails.join(','), subject: "Gribouille du #{l next_delivery.date, format: :short}")
              csv_link = link_to('liste', gribouille_emails_members_path(format: :csv))
              "#{emails.size} emails amoureux de Gribouille: #{mail_link} / #{csv_link}".html_safe
            else
              em 'Aucune prochaine livraison agendée.'
            end
          end
        end

        panel "Facturation #{Current.fy_year}" do
          billing_totals = BillingTotal.all
          billing_totals_price = billing_totals.sum(&:price)

          table_for billing_totals do
            column "Chiffre d'Affaire", :title
            column(class: 'align-right') { |total| number_to_currency(total.price) }
          end

          table_for nil do
            column(class: 'align-right') { "Total: #{number_to_currency(billing_totals_price)}" }
          end

          table_for InvoiceTotal.all(billing_totals_price) do
            column 'Facturation', :title
            column(class: 'align-right') { |total| number_to_currency(total.price) }
          end

          table_for nil do
            column do
              span do
                link_to 'Récapitulatif Excel', billing_path(Current.fy_year, format: :xlsx)
              end
            end
          end
        end
      end

      column do
        if next_delivery
          panel "Prochaine livraison: #{l next_delivery.date, format: :long}" do
            counts = BasketCount.all(next_delivery)
            if counts.present?
              table_for counts do
                column 'Lieu', :title
                column 'Paniers', :count, class: 'align-right'
                column "#{BasketSize.pluck(:name).join(' /&nbsp;')}".html_safe, :baskets_count, class: 'align-right'
              end

              if Distribution.paid.any?
                free_distributions = Distribution.free
                paid_distributions = Distribution.paid
                free_counts = counts.select { |c| c.distribution_id.in?(free_distributions.pluck(:id)) }
                paid_counts = counts.select { |c| c.distribution_id.in?(paid_distributions.pluck(:id)) }
                totals = [
                  OpenStruct.new(
                    title: "Paniers: #{free_distributions.pluck(:name).to_sentence}",
                    count: "Total: #{free_counts.sum(&:count)}",
                    baskets_count: "Totaux: #{free_counts.sum { |c| c.basket_sizes_count[0] }} / #{free_counts.sum { |c| c.basket_sizes_count[1] }}"),
                  OpenStruct.new(
                    title: 'Paniers à préparer',
                    count: "Total: #{paid_counts.sum(&:count)}",
                    baskets_count: "Totaux: #{paid_counts.sum { |c| c.basket_sizes_count[0] }} / #{paid_counts.sum { |c| c.basket_sizes_count[1] }}")
                ]
                table_for totals do
                  column nil, :title
                  column nil, :count, class: 'align-right'
                  column nil, :baskets_count, class: 'align-right'
                end
              end

              table_for nil do
                column nil, :title
                column(class: 'align-right') { "Total: #{counts.sum(&:count)}" }
                column(class: 'align-right') do
                  "Totaux: #{counts.sum { |c| c.basket_sizes_count[0] }} / #{counts.sum { |c| c.basket_sizes_count[1] }}"
                end
              end

              if BasketComplement.any?
                counts = BasketComplementCount.all(next_delivery)
                div id: 'basket-complements-table' do
                  if counts.any?
                    table_for counts do
                      column 'Complément', :title
                      column 'Total', :count, class: 'align-right'
                    end
                  else
                    em 'Aucun complément pour cette livraison'
                  end
                end
              end

              span do
                link_to 'Récapitulatif Excel', delivery_path(Delivery.next, format: :xlsx)
              end
              span { '&nbsp;/&nbsp;'.html_safe }
              span do
                link_to 'Fiches signature', delivery_path(Delivery.next, format: :pdf)
              end

              absences_count = next_delivery.baskets.absent.count
              if absences_count.positive?
                span class: 'delivery_absences' do
                  link_to "Absences: #{absences_count}", absences_path(q: { including_date: next_delivery.date.to_s })
                end
              end
            end

            if authorized?(:update, Delivery)
              span class: 'delivery_note' do
                form_for next_delivery do |f|
                  f.text_area :note
                  f.submit 'Mettre à jour la note'
                end
              end
            end
          end
        end

        panel "#{halfdays_human_name} (#{Current.fy_year})" do
          table_for HalfdayParticipationCount.all(Current.fy_year) do
            column('Statut') { |count| link_to_if(count.url, count.title, count.url) }
            column 'Nombres (am+pm * participants)', :count, class: 'align-right'
          end
        end
      end
    end
  end
end
