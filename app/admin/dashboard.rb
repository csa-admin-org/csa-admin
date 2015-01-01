ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Tableau de bord'

  content title: 'Tableau de bord' do
    next_delivery_date = Delivery.coming.first.try(:date)
    columns do
      column do
        panel 'Membres' do
          statuses = %i[pending waiting trial active support inactive]
          table_for statuses do
            column 'Status', ->(status) { link_to I18n.t("member.status.#{status}"), members_path(scope: status) }
            column 'Membres', ->(status) { Member.send(status).count }
            column 'Détails' do |status|
              if status.in?(%i[pending waiting trial active])
                members = Member.send(status).all.to_a
                Basket.all.map { |basket|
                  "#{basket.name}: #{members.count{ |m| m.basket == basket }}"
                }.join(' / ')
              end
            end
          end
        end
        panel "Facturation #{Date.today.year} (prévision)" do
          types = %w[Eveil Abondance Soutien]
          table_for types do
            column('Type') { |type| type }
            column('') do |type|
              div class: 'price' do
                number_to_currency Billing.total_price(type)
              end
            end
          end
          para do
            div class: 'excel_link' do
              link_to 'Fichier Excel', billing_path(format: :xls)
            end
            div class: 'total_price' do
              "Total: #{number_to_currency Billing.total_price}"
            end
          end
        end
      end
      column do
        members = Member.active.merge(Membership.including_date(next_delivery_date)).includes(:current_membership).to_a
        panel "Prochaine livraison: #{ l next_delivery_date, format: :long } (#{members.size} paniers)" do
          table_for Distribution.joins(:memberships).merge(Membership.including_date(next_delivery_date)).distinct.order(:id).all do |distribution|
            column 'Lieu', ->(distribution) { distribution.display_name }
            column 'Paniers' do |distribution|
              members.count { |m| m.current_membership.distribution_id == distribution.id }
            end
            column 'Détails', ->(distribution) do
              Basket.all.map { |basket|
                "#{basket.name}: #{members.count { |m| m.current_membership.distribution_id == distribution.id && m.current_membership.basket_id == basket.id }}"
              }.join(' / ')
            end
          end
        end
        panel 'Gribouille' do
          emails = Member.gribouille_emails
          str = "#{emails.count} emails amoureux de Gribouille: "
          str << mail_to('', 'mailto', bcc: emails.join(','), subject: "Gribouille du #{l next_delivery_date, format: :short}")
          str << " / "
          str << link_to('liste', gribouille_emails_members_path(format: :csv))
          str.html_safe
        end
        panel '½ Journées de travail' do
          '...'
        end
      end
    end
  end
end
