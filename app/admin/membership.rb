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
    column halfdays_human_name,
      -> (m) { auto_link m, "#{m.validated_halfday_works} / #{m.halfday_works}" },
      sortable: 'halfday_works', class: 'col-halfday_works'
    column :baskets_count
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
          table_for(m.baskets.includes(
            :delivery,
            :basket_size,
            :distribution,
            :complements,
            baskets_basket_complements: :basket_complement
          ),
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

        attributes_table title: 'Description' do
          row(:basket_size) { basket_size_description(m) }
          row :distribution
          if BasketComplement.any?
            row(:memberships_basket_complements) {
              basket_complements_description(
                m.memberships_basket_complements.includes(:basket_complement))
            }
          end
        end

        attributes_table title: halfdays_human_name do
          row("Demandées") { m.halfday_works }
          row("Validées") { m.validated_halfday_works }
        end

        attributes_table title: 'Facturation' do
          if m.member.try(:salary_basket?)
            em 'Gratuit, panier salaire'
          elsif m.baskets_count.zero?
            em 'Pas de paniers'
          else
            row(:basket_sizes_price) {
              display_price_description(m.basket_sizes_price, basket_sizes_price_info(m.baskets))
            }
            row(:baskets_annual_price_change) {
              number_to_currency(m.baskets_annual_price_change)
            }
            if m.basket_complements.any?
              row(:basket_complements_price) {
                display_price_description(m.basket_complements_price, basket_complements_price_info(m.baskets))
              }
            end
            row(:distributions_price) {
              display_price_description(m.distributions_price, distributions_price_info(m.baskets))
            }
            row(halfday_scoped_attribute(:halfday_works_annual_price)) { number_to_currency(m.halfday_works_annual_price) }
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

    unless resource.new_record?
      f.inputs halfdays_human_name do
        f.input :annual_halfday_works,
          label: "#{halfdays_human_name} (année complète)",
          hint: 'Laisser blanc pour le nombre par défaut.'
        f.input :halfday_works_annual_price,
          label: "Ajustement du prix de l'abonnement",
          hint: "Augmentation ou réduction du prix de l\'abonnement contre service (#{halfdays_human_name}) rendu ou non."
      end
    end

    f.inputs 'Panier et distribution' do
      unless resource.new_record?
        em 'Attention, toute modification recréera tous les paniers à venir de cet abonnement!'
      end
      f.input :basket_size, include_blank: false
      f.input :basket_price, hint: 'Laisser blanc pour le prix par défaut.'
      f.input :baskets_annual_price_change,
        label: "Ajustement du prix de l'abonnement",
        hint: "Modifie le montant final, peu importe le nombre de paniers."
      f.input :basket_quantity
      f.input :distribution, include_blank: false
      f.input :distribution_price, hint: 'Laisser blanc pour le prix par défaut.'
      if Current.acp.seasons?
        f.input :seasons,
          as: :check_boxes,
          collection: seasons_collection,
          hint: 'Les paniers avec une date de livraion hors saison auront leur quantité réduite à zéro.'
      end

      if BasketComplement.any?
        f.has_many :memberships_basket_complements, allow_destroy: true do |ff|
          ff.input :basket_complement, collection: BasketComplement.all, prompt: 'Choisir un complément:'
          ff.input :price, hint: 'Laisser blanc pour le prix par défaut.'
          ff.input :quantity
          if Current.acp.seasons?
            ff.input :seasons,
              as: :check_boxes,
              collection: seasons_collection,
              hint: 'Les paniers avec une date de livraion hors saison auront leur quantité réduite à zéro.'
          end
        end
      end
    end
    f.actions
  end

  permit_params \
    :member_id,
    :basket_size_id, :basket_price, :basket_quantity, :baskets_annual_price_change,
    :distribution_id, :distribution_price,
    :started_on, :ended_on, :renew,
    :halfday_works_annual_price, :annual_halfday_works,
    seasons: [],
    memberships_basket_complements_attributes: [
      :id, :basket_complement_id,
      :price, :quantity,
      :_destroy,
      seasons: []
    ]
  includes :member, :delivered_baskets

  before_build do |membership|
    fy_range = Delivery.next.fy_range
    membership.member_id ||= params[:member_id]
    membership.basket_size_id ||= params[:basket_size_id]
    membership.distribution_id ||= params[:distribution_id]
    membership.started_on ||= params[:started_on] || fy_range.min
    membership.ended_on ||= fy_range.max
  end

  config.per_page = 30
  config.comments = true
end
