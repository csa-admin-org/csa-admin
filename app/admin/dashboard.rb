ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Tableau de bord'
  year = Time.zone.today.year

  content title: 'Tableau de bord' do
    next_delivery = Delivery.coming.first
    columns do
      column do
        panel 'Membres' do
          table_for MemberCount.all do
            column('Status') { |count| link_to count.title, members_path(scope: count.scope) }
            column 'Membres', class: 'align-right' do |count|
              count.count.to_s.prepend(count.count_precision.to_s)
            end
            column "#{Basket::SMALL} / #{Basket::BIG}", class: 'align-right' do |count|
              [count.count_small_basket, count.count_big_basket].compact.join(' / ')
            end
          end
        end

        panel "Facturation #{year}" do
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
              xlsx_link = link_to 'Excel', billing_path(format: :xlsx)
              "Télécharger : #{xlsx_link}".html_safe
            end
          end
        end
      end

      column do
        panel "Prochaine livraison: #{l next_delivery.date, format: :long}" do
          counts = DistributionCount.all(next_delivery)
          if counts.present?
            table_for counts do
              column 'Lieu', :title
              column 'Paniers', :count, class: 'align-right'
              column "#{Basket::SMALL} / #{Basket::BIG}", :baskets_count, class: 'align-right'
            end

            jardin_count = counts.find { |c| c.title == 'Jardin de la Main' }
            other_counts = counts.reject { |c| c.title == 'Jardin de la Main' }
            totals = [
              OpenStruct.new(
                title: 'Paniers Jardin de la Main',
                count: "Total: #{jardin_count.count}",
                baskets_count: "Totaux: #{jardin_count.baskets_count}"),
              OpenStruct.new(
                title: 'Paniers à préparer',
                count: "Total: #{other_counts.sum(&:count)}",
                baskets_count: "Totaux: #{other_counts.sum(&:count_small_basket)} / #{other_counts.sum(&:count_big_basket)}")
            ]
            table_for totals do
              column nil, :title
              column nil, :count, class: 'align-right'
              column nil, :baskets_count, class: 'align-right'
            end

            table_for nil do
              column do
                xlsx_link = link_to 'Excel', delivery_path(Delivery.coming.first, format: :xlsx)
                "Télécharger : #{xlsx_link}".html_safe
              end
              column(class: 'align-right') { "Total: #{counts.sum(&:count)}" }
              column(class: 'align-right') do
                "Totaux: #{counts.sum(&:count_small_basket)} / #{counts.sum(&:count_big_basket)}"
              end
            end
          end

          absences_count = Absence.including_date(next_delivery.date).count
          if absences_count.positive?
            span class: 'delivery_absences' do
              link_to "Absences: #{absences_count}", absences_path(q: { including_date: next_delivery.date.to_s })
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

        panel "½ Journées de travail (#{year})" do
          table_for HalfdayParticipationCount.all(year) do
            column 'Status', :title
            column 'Nombres (am+pm * participants)', :count, class: 'align-right'
          end
        end

        panel 'Gribouille' do
          emails = Member.gribouille_emails
          mail_link = mail_to('', 'mailto', bcc: emails.join(','), subject: "Gribouille du #{l next_delivery.date, format: :short}")
          csv_link = link_to('liste', gribouille_emails_members_path(format: :csv))

          "#{emails.size} emails amoureux de Gribouille: #{mail_link} / #{csv_link}".html_safe
        end
      end
    end
  end
end
