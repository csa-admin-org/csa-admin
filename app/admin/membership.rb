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
    column :baskets_count, -> (m) { auto_link m, "#{m.delivered_baskets.size} / #{m.baskets_count}" }
    actions
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:memberships).order(:last_name).distinct }
  filter :started_on
  filter :ended_on

  show do |m|
    columns do
      column do
        panel "#{m.baskets_count} Paniers" do
          table_for(m.baskets.includes(:delivery, :basket_size, :distribution),
            row_class: ->(b) { 'next' if b.next? },
            class: 'table-baskets'
          ) do |basket|
            column(:delivery)
            column(:basket_size)
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
        attributes_table title: "Détails" do
          row :id
          row :member
          row(:started_on) { l m.started_on }
          row(:ended_on) { l m.ended_on }
          row :annual_halfday_works
        end

        attributes_table title: "Facturation" do
          if m.member.try(:salary_basket?)
            em 'Gratuit, panier salaire'
          elsif m.baskets_count.zero?
            em 'Pas de paniers'
          else
            row(:basket_total_price) {
              "#{number_to_currency(m.basket_total_price)} (#{m.basket_total_price_details})"
            }
            row(:distribution_total_price) {
              "#{number_to_currency(m.distribution_total_price)} (#{m.distribution_total_price_details})"
            }
            row(:halfday_works_total_price) { number_to_currency(m.halfday_works_total_price) }
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
        collection: Member.order(:last_name).map { |d| [d.name, d.id] },
        include_blank: false
    end
    f.inputs 'Dates' do
      years_range = Delivery.years_range
      f.input :started_on, start_year: years_range.first, include_blank: false
      f.input :ended_on, start_year: years_range.first, end_year: years_range.last, include_blank: false
    end
    f.inputs 'Panier & Distribution' do
      f.input :basket_size_id,
        as: :select,
        collection: BasketSize.all,
        include_blank: !resource.new_record?,
        hint: !resource.new_record? && 'Seulement les paniers à venir seront modifiés.'
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

  permit_params *%i[
    member_id
    basket_size_id distribution_id
    started_on ended_on
    halfday_works_annual_price annual_halfday_works
  ]

  controller do
    def build_resource
      super
      resource.member_id ||= params[:member_id]
      resource.basket_size_id ||= params[:basket_size_id]
      resource.distribution_id ||= params[:distribution_id]
      resource.started_on ||= params[:started_on] || Delivery.next_coming_date.beginning_of_year
      resource.ended_on ||= Delivery.next_coming_date.end_of_year
      resource
    end

    def scoped_collection
      Membership.includes(:member, :delivered_baskets)
    end
  end

  config.per_page = 30
  config.comments = true
end
