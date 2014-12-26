ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Tableau de bord'

  content title: 'Tableau de bord' do
    columns do
      column do
        panel 'Membres' do
          statuses = %i[waiting_validation waiting_list active support inactive]
          table_for statuses do
            column 'Status', ->(status) { I18n.t("member.status.#{status}") }
            column 'Membres', ->(status) { Member.send(status).count }
            column 'Détails' do |status|
              if status.in?(%i[waiting_list active])
                Basket.all.map { |basket|
                  "#{basket.name}: #{Member.send(status).with_current_basket(basket).count}"
                }.join(' / ')
              end
            end
          end
        end
      end
      column do
        panel 'Facturation' do
          ul do
            li para '...'
          end
        end
      end
      # column do
      #   panel 'Distributions' do
      #     distribution_counts = Member.active.group(:distribution_id).count
      #     table_for Distribution.all do
      #       column 'Lieu', ->(distribution) { "#{distribution.city} (#{distribution.name})" }
      #       column '', ->(distribution) { distribution_counts[distribution.id].to_i }
      #     end
      #   end
      # end
    end
    columns do
      column do
        next_delivery_date = Delivery.coming.first.try(:date)
        members = Member.active.merge(Membership.with_date(next_delivery_date)).includes(:current_membership).to_a
        panel "Prochaine livraison: #{ l next_delivery_date, format: :long } (#{members.size} paniers)" do
          table_for Distribution.joins(:memberships).merge(Membership.with_date(next_delivery_date)).distinct.order(:id).all do |distribution|
            column 'Lieu', ->(distribution) { "#{distribution.city} (#{distribution.name})" }
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
      end
      column do
        panel '½ Journées de travail' do
          ul do
            li para '...'
          end
        end
      end
    end
  end
end
