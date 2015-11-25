ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Tableau de bord'
  year = Time.zone.today.year

  content title: 'Tableau de bord' do
    next_delivery = Delivery.coming.first
    small_basket = Basket.current_small
    big_basket = Basket.current_big
    columns do
      column do
        panel 'Membres' do
          statuses = %i[pending waiting trial active support inactive]
          table_for statuses do
            column 'Status', ->(status) {
              link_to I18n.t("member.status.#{status}"), members_path(scope: status)
            }
            column 'Membres', class: 'align-right' do |status|
              str = ''
              if status == :active
                str += "(#{Member.where(salary_basket: true).count} panier-salaire) "
              end
              if status == :inactive
                str += "(#{Member.inactive.joins(:memberships).merge(Membership.future).count} futur actif) "
              end
              str += Member.send(status).count.to_s
            end
            column "#{small_basket.name} / #{big_basket.name}", class: 'align-right' do |status|
              if status.in?(%i[pending waiting trial active inactive])
                members = Member.send(status).includes(:waiting_basket, current_membership: :basket).all.to_a
                count_small_basket = members.count{ |m| m.basket == small_basket }
                count_big_basket = members.count{ |m| m.basket == big_basket }
                [count_small_basket, count_big_basket].join(' / ').html_safe
              end
            end
          end
        end
        panel "Facturation #{year} (prévision, sans les paniers à l'essai)" do
          billable_memberships = Membership.billable
          total_price = 0
          types = ['Paniers Eveil', 'Paniers Abondance', 'Cotisations']
          table_for types do
            column('Type') { |type| type }
            column('', class: 'align-right') do |type|
              price = case type
              when /Eveil/, /Abondance/
                basket_name = type.sub /Paniers /, ''
                billable_memberships
                  .select { |m| m.basket.name == basket_name }
                  .sum(&:price)
              when 'Cotisations'
                Member.billable.select(&:support_billable?).size * Member::SUPPORT_PRICE
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
        panel 'Gribouille' do
          emails = Member.gribouille_emails
          str = "#{emails.count} emails amoureux de Gribouille: "
          str << mail_to('', 'mailto', bcc: emails.join(','), subject: "Gribouille du #{l next_delivery.date, format: :short}")
          str << " / "
          str << link_to('liste', gribouille_emails_members_path(format: :csv))
          str.html_safe
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
          table_for [false, true] do |delivered|
            column('') do |delivered|
              delivered ? 'Paniers à préparer' : 'Paniers Jardin de la Main'
            end
            column('', class: 'align-right') do |delivered|
              if delivered
                tot = distributions.sum { |d| d.delivery_memberships.to_a.count { |m| m.distribution_id != 1 } }
              else
                tot = distributions.sum { |d| d.delivery_memberships.to_a.count { |m| m.distribution_id == 1 } }
              end
              "Total: #{tot}"
            end
            column('', class: 'align-right') do |delivered|
              if delivered
                count_small_basket = distributions.sum { |d| d.delivery_memberships.to_a.count { |m| m.distribution_id != 1 && m.basket_id == small_basket.id } }
                count_big_basket = distributions.sum { |d| d.delivery_memberships.to_a.count { |m| m.distribution_id != 1 && m.basket_id == big_basket.id } }
              else
                count_small_basket = distributions.sum { |d| d.delivery_memberships.to_a.count { |m| m.distribution_id == 1 && m.basket_id == small_basket.id } }
                count_big_basket = distributions.sum { |d| d.delivery_memberships.to_a.count { |m| m.distribution_id == 1 && m.basket_id == big_basket.id } }
              end
              spaced("Totaux: #{[count_small_basket, count_big_basket].join(' / ')}", size: 33)
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
          absences_count = Absence.including_date(next_delivery.date).count
          if absences_count > 0
            span do
              link_to "Absences: #{absences_count}", absences_path(q: { including_date: next_delivery.date.to_s })
            end
          end
        end
        panel "½ Journées de travail (#{year})" do
          coming_halfday_works = HalfdayWork.during_year(year).coming.to_a.sum(&:value)
          pending_halfday_works = HalfdayWork.during_year(year).pending.to_a.sum(&:value)
          validated_halfday_works = HalfdayWork.during_year(year).validated.to_a.sum(&:value)
          rejected_halfday_works = HalfdayWork.during_year(year).rejected.to_a.sum(&:value)

          statuses = %i[coming pending validated rejected missing]
          table_for statuses do
            column 'Status', ->(status) {
              I18n.t("active_admin.scopes.#{status}")
            }
            column 'Nombres (am+pm * participants)', class: 'align-right' do |status|
              halfday_works =
                case status
                when :coming then coming_halfday_works
                when :pending then pending_halfday_works
                when :validated then validated_halfday_works
                when :rejected then rejected_halfday_works
                when :missing
                  total = Member.active.to_a.sum(&:annual_halfday_works)
                  done = coming_halfday_works + pending_halfday_works + validated_halfday_works
                  "(#{total} - #{done}) #{total - done}"
                end
            end
          end
        end
      end
    end
  end
end
