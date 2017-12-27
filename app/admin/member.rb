ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :pending
  scope :waiting
  scope :trial
  scope :active, default: true
  scope :inactive

  index do
    if params[:scope] == 'waiting'
      @waiting_started_ats ||= Member.waiting.order(:waiting_started_at).pluck(:waiting_started_at)
      column '#', ->(member) {
        @waiting_started_ats.index(member.waiting_started_at) + 1
      }, sortable: :waiting_started_at
    end
    column :name, ->(member) { link_to member.name, member }, sortable: :last_name
    column :city, ->(member) { member.city? ? "#{member.city} (#{member.zip})" : nil }
    column :state, ->(member) { status_tag(member.state) }
    if params[:scope] == 'trial'
      column 'Paniers', ->(member) { member.delivered_baskets.size }
    end
    actions
  end

  show do |member|
    columns do
      column do
        panel "Abonnements" do
          memberships = member.memberships.order(:started_on)
          if memberships.none?
            em "Aucun abonnement"
          else
            table_for(memberships, class: 'table-memberships') do |basket|
              column(:description) { |m| auto_link m, m.short_description }
              column(:baskets) { |m| auto_link m, "#{m.delivered_baskets.size} / #{m.baskets_count}" }
            end
          end
        end

        panel "½ Journées" do
          halfday_participations = member.halfday_participations.includes(:halfday).order('halfdays.date, halfdays.start_time')
          if halfday_participations.none?
            em "Aucune ½ journée"
          else
            table_for(halfday_participations, class: 'table-halfday_participations') do |basket|
              column('Description') { |hp|
                link_to hp.halfday.name, halfday_participations_path(q: { halfday_id_eq: hp.halfday_id }, scope: :all)
              }
              column('Part. #') { |hp| hp.participants_count }
              column(:state) { |hp| status_tag(hp.state) }
            end
          end
        end

        panel "Factures" do
          invoices = member.invoices.order(:date)
          if invoices.none?
            em "Aucune facture"
          else
            table_for(invoices, class: 'table-invoices') do |invoice|
              column(:date) { |i| auto_link i, l(i.date, format: :number) }
              column(:amount) { |i| number_to_currency(i.amount) }
              column(:balance) { |i| number_to_currency(i.balance) }
              column(:overdue_notices_count)
              column(class: 'col-actions') { |i|
                link_to 'PDF', pdf_invoice_path(i), class: 'pdf_link', target: '_blank'
              }
              column(:status) { |i| status_tag i.status }
            end
          end
        end
      end

      column do
        attributes_table title: 'Détails' do
          row :id
          row :name
          row(:status) { status_tag member.state }
          row(:created_at) { l member.created_at }
          row(:validated_at) { member.validated_at ? l(member.validated_at) : nil }
          row :validator
          row :renew_membership
        end
        if member.pending? || member.waiting?
          attributes_table title: 'Abonnement (en attente)' do
            row :waiting_started_at
            row :waiting_basket_size
            row :waiting_distribution
          end
        end
        attributes_table title: 'Adresse' do
          row(:address) { member.display_address }
          unless member.same_delivery_address?
            row(:delivery_address) { member.display_delivery_address }
          end
        end
        attributes_table title: 'Contact' do
          row :phones
          row :emails
          row(:gribouille) { status_tag(member.gribouille? ? :yes : :no) }
        end
        attributes_table title: 'Facturation' do
          row(:billing_interval) { t("member.billing_interval.#{member.billing_interval}") }
          row(:salary_basket) { member.salary_basket? ? 'oui' : 'non' }
        end
        attributes_table title: 'Notes' do
          row :food_note
          row :note
        end

        active_admin_comments
      end
    end
  end

  filter :with_name, as: :string
  filter :with_address, as: :string
  filter :city, as: :select, collection: -> {
    Member.pluck(:city).uniq.map(&:presence).compact.sort
  }
  filter :billing_interval, as: :select, collection: Member::BILLING_INTERVALS.map { |i| [I18n.t("member.billing_interval.#{i}"), i] }
  filter :renew_membership, as: :boolean

  action_item :create_invoice, only: :show, if: -> { resource.billable? && authorized?(:create, Invoice) } do
    link_to 'Créer facture', create_invoice_member_path(resource), method: :post
  end
  action_item :validate, only: :show, if: -> { resource.pending? && authorized?(:update, Member) } do
    link_to 'Valider', validate_member_path(resource), method: :post
  end
  action_item :remove_from_waiting_list, only: :show, if: -> { resource.waiting? && authorized?(:update, Member) } do
    link_to "Retirer de la liste d'attente", remove_from_waiting_list_member_path(resource), method: :post
  end
  action_item :put_back_to_waiting_list!, only: :show, if: -> { resource.inactive? && authorized?(:update, Member) } do
    link_to "Remettre en liste d'attente", put_back_to_waiting_list_member_path(resource), method: :post
  end
  action_item :create_membership, only: :show, if: -> { resource.waiting? && authorized?(:create, Membership) } do
    link_to 'Créer abonnement',
      new_membership_path(
        member_id: resource.id,
        basket_size_id: resource.waiting_basket_size_id,
        distribution_id: resource.waiting_distribution_id,
        started_on: Date.current)
  end

  form do |f|
    f.inputs 'Details' do
      f.input :first_name
      f.input :last_name
      f.input :renew_membership unless resource.new_record?
    end
    if member.pending? || member.waiting?
      f.inputs 'Abonnement (en attente)' do
        f.input :waiting_basket_size, label: 'Panier'
        f.input :waiting_distribution, label: 'Distribution'
      end
    end
    f.inputs 'Adresse' do
      f.input :address
      f.input :city
      f.input :zip
    end
    f.inputs 'Adresse (Livraison)' do
      f.input :delivery_address, hint: 'laisser vide si identique'
      f.input :delivery_city, hint: 'laisser vide si identique'
      f.input :delivery_zip, hint: 'laisser vide si identique'
    end
    f.inputs 'Contact' do
      f.input :emails, hint: "séparés par ', '"
      f.input :phones, hint: "séparés par ', '"
      f.input :gribouille, as: :select,
        collection: [['Oui', true], ['Non', false]],
        hint: 'laisser vide pour le comportement par défault (en fonction du statut)'
    end
    f.inputs 'Facturation' do
      f.input :billing_interval,
        collection: Member::BILLING_INTERVALS.map { |i| [I18n.t("member.billing_interval.#{i}"), i] },
        include_blank: false
      f.input :support_member
      f.input :salary_basket, label: 'Panier(s) salaire / Abonnement(s) gratuit(s)'
    end
    f.inputs 'Notes' do
      f.input :food_note, input_html: { rows: 3 }
      f.input :note, input_html: { rows: 3 }
    end
    f.actions
  end

  permit_params %i[
    first_name last_name address city zip emails phones gribouille
    delivery_address delivery_city delivery_zip
    support_member salary_basket billing_interval waiting
    waiting_basket_size_id waiting_distribution_id
    food_note note
    renew_membership
  ]

  collection_action :gribouille_emails, method: :get do
    render plain: Member.gribouille_emails.to_csv
  end

  member_action :validate, method: :post do
    resource.validate!(current_admin)
    redirect_to member_path(resource)
  end

  member_action :remove_from_waiting_list, method: :post do
    resource.remove_from_waiting_list!
    redirect_to member_path(resource)
  end

  member_action :put_back_to_waiting_list, method: :post do
    resource.put_back_to_waiting_list!
    redirect_to member_path(resource)
  end

  member_action :create_invoice, method: :post do
    InvoiceCreator.new(resource).create
    redirect_to invoices_path(q: { member_id_eq: resource.id }, scope: :all)
  end

  controller do
    def apply_sorting(chain)
      params[:order] ||= 'waiting_started_at_asc' if params[:scope] == 'waiting'
      super
    end

    def scoped_collection
      if params[:scope] == 'trial'
        Member.includes(:delivered_baskets)
      else
        Member.all
      end
    end

    def find_resource
      Member.find_by(token: params[:id])
    end

    def create_resource(object)
      run_create_callbacks object do
        object.validated_at = Time.current
        object.validator = current_admin
        save_resource(object)
      end
    end
  end

  config.per_page = 50
  config.sort_order = 'last_name_asc'
end
