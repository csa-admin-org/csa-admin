ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Tableau de bord'

  content title: 'Tableau de bord' do
    next_delivery = Delivery.coming.first
    columns do
      column do
        panel 'Membres' do
          statuses = %i[pending waiting trial active support inactive]
          table_for statuses do
            column 'Status', ->(status) { link_to I18n.t("member.status.#{status}"), members_path(scope: status) }
            column 'Membres', class: 'align-right' do |status|
              Member.send(status).count
            end
            column 'Détails', class: 'align-right' do |status|
              if status.in?(%i[pending waiting trial active])
                members = Member.send(status).all.to_a
                Basket.all.map { |basket|
                  "#{basket.name}: #{members.count{ |m| m.basket == basket }}"
                }.join(' / ')
              end
            end
          end
        end
        panel "Facturation #{Date.today.year} (prévision, sans les paniers à l'essai)" do
          total_price = 0
          types = %w[Eveil Abondance Soutien]
          table_for types do
            column('Type') { |type| type }
            column('', class: 'align-right') do |type|
              price = case type
              when 'Abondance', 'Eveil'
                Membership.billable.select { |m| m.basket.name == type }.sum(&:price)
              when 'Soutien'
                Member.support.count * Member::SUPPORT_PRICE
              end
              total_price += price
              number_to_currency price
            end
          end
          para do
            div class: 'excel_link' do
              link_to 'Fichier Excel', billing_path(format: :xlsx)
            end
            div class: 'total_price' do
              "Total: #{number_to_currency total_price}"
            end
          end
        end
      end
      column do
        panel "Prochaine livraison: #{ l next_delivery.date, format: :long }" do
          distributions = Distribution.with_delivery_memberships(next_delivery)
          table_for distributions do |distribution|
            column 'Lieu', ->(distribution) { distribution.name }
            column 'Paniers', class: 'align-right' do |distribution|
              distribution.delivery_memberships.count
            end
            column('Détails', class: 'align-right') do |distribution|
              Basket.all.map { |basket|
                "#{basket.name}: #{distribution.delivery_memberships.to_a.count { |m| m.distribution_id == distribution.id && m.basket_id == basket.id }}"
              }.join(' / ')
            end
          end
          para do
            div class: 'excel_link' do
              link_to 'Fichier Excel', delivery_path(Delivery.coming.first, format: :xlsx)
            end
            div class: 'total_deliveries' do
              "Total: #{distributions.sum { |d| d.delivery_memberships.count }}"
            end
            div class: 'total_deliveries_basket' do
              Basket.all.map { |basket|
                "#{basket.name}: #{distributions.sum { |d| d.delivery_memberships.select { |m| m.basket_id == basket.id }.count }}"
              }.join(' / ')
            end
            div do
             '&nbsp;'.html_safe
            end
          end
        end
        panel 'Gribouille' do
          emails = Member.gribouille_emails
          str = "#{emails.count} emails amoureux de Gribouille: "
          str << mail_to('', 'mailto', bcc: emails.join(','), subject: "Gribouille du #{l next_delivery.date, format: :short}")
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
