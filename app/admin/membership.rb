ActiveAdmin.register Membership do
  menu priority: 3

  scope :all
  scope :past
  scope :current, default: true
  scope :future_current_year
  scope :renew

  index do
    selectable_column
    column :member, ->(m) { link_to m.member.name, m.member }
    column :basket
    column :distribution
    column :started_on, ->(m) { l m.started_on }
    column :ended_on, ->(m) { l m.ended_on }
    actions
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:memberships).order(:last_name).distinct }
  filter :basket
  filter :distribution
  filter :started_on
  filter :ended_on

  show do |m|
    attributes_table do
      row :id
      row :member
      row :basket
      row :distribution
      row :annual_halfday_works
      row :deliveries_received_count
      row :deliveries_count
      if m.member.try(:salary_basket?)
        row(:price) { 'Gratuit, panier salaire' }
      else
        row(:basket_total_price) {
          detail = "#{m.deliveries_count} * #{m.basket.price}"
          "#{number_to_currency(m.basket_total_price)} (#{detail})"
        }
        row(:distribution_total_price) {
          detail = "#{m.deliveries_count} * #{m.distribution_basket_price}"
          "#{number_to_currency(m.distribution_total_price)} (#{detail})"
        }
        row(:halfday_works_total_price) {
          number_to_currency(m.halfday_works_total_price)
        }
        row(:price) {
          detail = [
            m.basket_total_price,
            m.distribution_total_price,
            m.halfday_works_total_price
          ].map { |price| number_to_currency(price, unit: '') }
          "#{number_to_currency(m.price)} (#{detail.join(' + ')})"
        }
      end
      row(:started_on) { l m.started_on }
      row(:ended_on) { l m.ended_on }
      row :note
    end
  end

  form do |f|
    f.inputs 'Membre' do
      f.input :member,
        collection: Member.valid_for_memberships.order(:last_name).map { |d| [d.name, d.id] },
        include_blank: false
    end
    f.inputs 'Panier & Distribution' do
      f.input :basket, include_blank: false
      f.input :distribution, include_blank: false
    end
    f.inputs '½ journée de travails' do
      f.input :annual_halfday_works
      f.input :halfday_works_annual_price, hint: 'augmentation ou réduction du prix de l\'abonnement contre service (½ journée de travails) rendu ou non.'
    end
    f.inputs 'Dates' do
      if membership.deliveries_received_count > 0
        collection = [
          ["début de l'abonnement", nil]
        ].concat(
          Delivery.coming.map { |d| ["panier ##{d.number} (#{d.date})", d.date] }
        )
        f.input :will_be_changed_at,
          collection: collection,
          include_blank: false,
          hint: "Si une date de panier à venir est sélectionnée, un nouvel abonnement sera
                 automatiquement créé à partir de cette date avec les nouvelles conditions. <br/>
                 Seule la date de fin de l'abonnement courant sera pas modifiée.".html_safe
      end
      years_range = Delivery.years_range
      f.input :started_on, start_year: years_range.first, include_blank: false
      f.input :ended_on, start_year: years_range.first, end_year: years_range.last, include_blank: false
    end
    f.inputs 'Note' do
      f.input :note, input_html: { rows: 5 }
    end

    f.actions
  end

  permit_params *%i[
    member_id basket_id distribution_id
    halfday_works_annual_price annual_halfday_works
    will_be_changed_at started_on ended_on note
  ]

  batch_action :renew do |selection|
    Membership.find(selection).each(&:renew)
    redirect_to collection_path
  end

  controller do
    def build_resource
      super
      resource.started_on ||= Time.zone.today.beginning_of_year
      resource.ended_on ||= Time.zone.today.end_of_year
      resource
    end

    def scoped_collection
      Membership.includes(:member, :basket, :distribution)
    end
  end

  config.per_page = 25
  config.batch_actions = true
end
