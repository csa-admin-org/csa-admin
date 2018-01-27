ActiveAdmin.register Membership do
  menu priority: 3

  scope :all
  scope :past
  scope :current, default: true
  scope :future

  index do
    column :member, ->(m) { auto_link m.member }
    column :started_on, ->(m) { l m.started_on, format: :number }
    column :ended_on, ->(m) { l m.ended_on, format: :number }
    column '½ journées',
      -> (m) { auto_link m, "#{m.validated_halfday_works} / #{m.halfday_works}" },
      sortable: 'halfday_works'
    column :baskets_count,
      -> (m) { auto_link m, "#{m.delivered_baskets.size} / #{m.baskets_count}" }
    actions
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:memberships).order(:name).distinct }
  filter :started_on
  filter :ended_on
  filter :renew

  show do |m|
    columns do
      column do
        panel "#{m.baskets_count} Paniers" do
          table_for(m.baskets.includes(:delivery, :basket_size, :distribution, :complements),
            row_class: ->(b) { 'next' if b.next? },
            class: 'table-baskets'
          ) do |basket|
            column(:delivery)
            column(:description)
            column(:distribution)
            column(class: 'col-status') { |b|
              status_tag(:trial) if b.trial?
              status_tag(:absent) if b.absent?
            }
            column(class: 'col-actions') { |b|
              link_to 'Modifier', edit_basket_path(b), class: 'edit_link'
            }
          end
        end
      end

      column do
        attributes_table title: 'Détails' do
          row :id
          row :member
          row(:started_on) { l m.started_on }
          row(:ended_on) { l m.ended_on }
          row :renew
        end

        if BasketComplement.any?
          panel 'Compléments Panier' do
            names = m.subscribed_basket_complements.pluck(:name)
            if names.present?
              names.to_sentence
            else
              em 'Aucun'
            end
          end
        end

        attributes_table title: "½ journées" do
          row :annual_halfday_works
          row :halfday_works
          row :validated_halfday_works
        end

        attributes_table title: 'Facturation' do
          if m.member.try(:salary_basket?)
            em 'Gratuit, panier salaire'
          elsif m.baskets_count.zero?
            em 'Pas de paniers'
          else
            row(:basket_sizes_price) {
              "#{number_to_currency(m.basket_sizes_price)} (#{m.basket_sizes_price_info})"
            }
            if m.basket_complements.any?
              row(:basket_complements_price) {
                "#{number_to_currency(m.basket_complements_price)} (#{m.basket_complements_price_info})"
              }
            end
            row(:distributions_price) {
              "#{number_to_currency(m.distributions_price)} (#{m.distributions_price_info})"
            }
            row(:halfday_works_price) { number_to_currency(m.halfday_works_price) }
            row(:price) { number_to_currency(m.price) }
          end
        end

        active_admin_comments
      end
    end
  end

  form do |f|
    f.inputs 'Membre' do
      f.input :member,
        collection: Member.order(:name).map { |d| [d.name, d.id] },
        include_blank: false
    end
    f.inputs 'Dates' do
      f.input :started_on, as: :datepicker, include_blank: false
      f.input :ended_on, as: :datepicker, include_blank: false
      f.input :renew unless resource.new_record? || resource.current_year?
    end
    f.inputs 'Panier & Distribution' do
      f.input :basket_size_id,
        as: :select,
        collection: BasketSize.all,
        include_blank: !resource.new_record?,
        hint: !resource.new_record? && 'Seulement les paniers à venir seront modifiés.'
      if BasketComplement.any?
        f.input :subscribed_basket_complement_ids,
          as: :check_boxes,
          collection: BasketComplement.all,
          hint: !resource.new_record? && 'Seulement les paniers à venir seront modifiés en fonction des livraisons agendées pour les compléments de panier.'
      end
      f.input :distribution_id,
        as: :select,
        collection: Distribution.all,
        include_blank: !resource.new_record?,
        hint: !resource.new_record? && 'Seulement les paniers à venir seront modifiés.'
    end
    unless resource.new_record?
      f.inputs '½ journée de travails' do
        f.input :annual_halfday_works
        f.input :halfday_works_annual_price, hint: 'Augmentation ou réduction du prix de l\'abonnement contre service (½ journée de travails) rendu ou non.'
      end
    end
    f.actions
  end

  permit_params \
    :member_id,
    :basket_size_id, :distribution_id,
    :started_on, :ended_on, :renew,
    :halfday_works_annual_price, :annual_halfday_works,
    subscribed_basket_complement_ids: []
  includes :member, :delivered_baskets

  controller do
    def build_resource
      super
      fy_range = Delivery.next.fy_range
      resource.member_id ||= params[:member_id]
      resource.basket_size_id ||= params[:basket_size_id]
      resource.distribution_id ||= params[:distribution_id]
      resource.started_on ||= params[:started_on] || fy_range.min
      resource.ended_on ||= fy_range.max
      resource
    end
  end

  config.per_page = 30
  config.comments = true
end
