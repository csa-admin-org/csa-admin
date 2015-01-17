ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Tableau de bord'

  content title: 'Tableau de bord' do
    next_delivery = Delivery.coming.first
    small_basket = Basket.current_small
    big_basket = Basket.current_big
    columns do
      column do
        panel 'Membres' do
          statuses = %i[pending waiting trial active support inactive]
          table_for statuses do
            column 'Status', ->(status) { link_to I18n.t("member.status.#{status}"), members_path(scope: status) }
            column 'Membres', class: 'align-right' do |status|
              Member.send(status).count
            end
            column "#{small_basket.name} / #{big_basket.name}", class: 'align-right' do |status|
              if status.in?(%i[pending waiting trial active])
                members = Member.send(status).includes(current_membership: :basket).all.to_a
                count_small_basket = members.count{ |m| m.basket == small_basket }
                count_big_basket = members.count{ |m| m.basket == big_basket }
                [count_small_basket, count_big_basket].join(' / ').html_safe
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
          table_for ['foo'] do |foo|
            column('') do
              "Télécharger : #{link_to 'Excel', billing_path(format: :xlsx)}".html_safe
            end
            column('', class: 'align-right') do
              "Total: #{number_to_currency total_price}"
            end
          end
        end
      end
      column do
        panel "Prochaine livraison: #{ l next_delivery.date, format: :long }" do
          distributions = Distribution.with_delivery_memberships(next_delivery)
          total_small_basket = 0
          total_big_basket = 0
          table_for distributions do |distribution|
            column 'Lieu', ->(distribution) { distribution.name }
            column('Paniers', class: 'align-right') do |distribution|
              distribution.delivery_memberships.count
            end
            column("#{small_basket.name} / #{big_basket.name}", class: 'align-right') do |distribution|
              count_small_basket = distribution.delivery_memberships.to_a.count { |m| m.basket_id == small_basket.id }
              count_big_basket = distribution.delivery_memberships.to_a.count { |m| m.basket_id == big_basket.id }
              total_small_basket += count_small_basket
              total_big_basket += count_big_basket
              [count_small_basket, count_big_basket].join(' / ').html_safe
            end
          end
          table_for ['foo'] do |foo|
            column('') do
              "Télécharger : #{link_to 'Excel', delivery_path(Delivery.coming.first, format: :xlsx)}".html_safe
            end
            column('', class: 'align-right') do
              "Total: #{total_small_basket + total_big_basket}"
            end
            column('', class: 'align-right') do
              spaced("Totaux: #{[total_small_basket, total_big_basket].join(' / ')}", size: 27)
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
