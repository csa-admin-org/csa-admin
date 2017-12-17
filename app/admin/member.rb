ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :pending
  scope :waiting
  scope :trial
  scope :active, default: true
  scope :support
  scope :inactive
  # scope :renew_membership

  index do
    selectable_column
    if params[:scope] == 'waiting'
      @waiting_started_ats ||= Member.waiting.order(:waiting_started_at).pluck(:waiting_started_at)
      column '#', ->(member) {
        @waiting_started_ats.index(member.waiting_started_at) + 1
      }, sortable: :waiting_started_at
    end
    column :name, ->(member) { link_to member.name, member }, sortable: :last_name
    column :city, ->(member) { member.city? ? "#{member.city} (#{member.zip})" : nil }
    column :current_membership do |member|
      if member.current_membership
        link_to "#{member.basket.name} / #{member.distribution.name}", member.current_membership
      else
        a = []
        a << link_to(member.waiting_basket.name, member.waiting_basket) if member.waiting_basket
        a << link_to(member.waiting_distribution.name, member.waiting_distribution) if member.waiting_distribution
        a.join(' / ').html_safe
      end
    end
    column :status, ->(member) { member.display_status }
    if params[:scope] == 'trial'
      column 'Essai(s)', ->(member) {
        member.deliveries_received_count_since_first_membership
      }
    end
    actions
  end

  show do |member|
    attributes_table do
      row :id
      row :name
      row(:address) { member.display_address }
      unless member.same_delivery_address?
        row(:delivery_address) { member.display_delivery_address }
      end
      row :phones
      row :emails
      row(:gribouille) { member.gribouille? ? 'envoyée' : 'non-envoyée' }
      row(:billing_interval) { t("member.billing_interval.#{member.billing_interval}") }
      row :current_membership do
        if member.current_membership
          link_to(
            "#{member.basket.name} / #{member.distribution.name}",
            member.current_membership
          )
        end
      end
      row :renew_membership
      row(:status) { member.display_status }
      if member.status == :trial
        row :deliveries_received_count_since_first_membership
      end
      if member.status == :waiting
        row :waiting_started_at
      end
      if member.status.in? %i[pending waiting]
        row :waiting_basket
        row :waiting_distribution
      end
      row :food_note
      row :note
      row(:created_at) { l member.created_at }
      row(:validated_at) { member.validated_at ? l(member.validated_at) : nil }
      row :validator
      row(:salary_basket) { member.salary_basket? ? 'oui' : 'non' }
    end
  end

  filter :with_name, as: :string
  filter :with_address, as: :string
  filter :city, as: :select, collection: -> {
    Member.pluck(:city).uniq.map(&:presence).compact.sort
  }
  filter :with_current_basket, as: :select, collection: -> { Basket.all }
  filter :with_current_distribution, as: :select, collection: -> { Distribution.all }
  filter :billing_interval, as: :select, collection: Member::BILLING_INTERVALS.map { |i| [I18n.t("member.billing_interval.#{i}"), i] }

  action_item :create_invoice, only: :show do
    link_to 'Créer facture', create_invoice_member_path(resource), method: :post
  end
  action_item :invoices, only: :show do
    link_to 'Factures', invoices_path(q: { member_id_eq: member.id }, scope: :all)
  end
  action_item :memberships, only: :show do
    link_to 'Abonnements', memberships_path(q: { member_id_eq: member.id }, scope: :all)
  end

  form do |f|
    f.inputs 'Details' do
      f.input :first_name
      f.input :last_name
      f.input :emails, hint: "séparés par ', '"
      f.input :phones, hint: "séparés par ', '"
      f.input :gribouille, as: :select,
        collection: [['envoyée', true], ['non-envoyée', false]],
        hint: 'laisser vide pour le comportement par défault (en fonction du status)'
      f.input :billing_interval,
        collection: Member::BILLING_INTERVALS.map { |i| [I18n.t("member.billing_interval.#{i}"), i] },
        include_blank: false
      f.input :support_member
      f.input :salary_basket, label: 'Panier(s) salaire / Abonnement(s) gratuit(s)'
      f.input :renew_membership
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
    f.inputs 'Notes' do
      f.input :food_note, input_html: { rows: 3 }
      f.input :note, input_html: { rows: 3 }
    end
    if member.new_record? || member.waiting_started_at_changed? || member.status.in?(%i[pending waiting])
      f.inputs "Abonnement" do
        f.input :waiting, as: :boolean
        f.input :waiting_basket, label: 'Panier'
        f.input :waiting_distribution, label: 'Distribution'
      end
    end
    f.actions
  end

  permit_params %i[
    first_name last_name address city zip emails phones gribouille
    delivery_address delivery_city delivery_zip
    support_member salary_basket billing_interval waiting
    waiting_basket_id waiting_distribution_id
    food_note note
    renew_membership
  ]

  batch_action :validate do |selection|
    Member.find(selection).each do |member|
      member.validate!(current_admin)
    end
    redirect_to collection_path
  end

  batch_action :wait do |selection|
    Member.find(selection).each do |member|
      member.wait!
    end
    redirect_to collection_path
  end

  collection_action :gribouille_emails, method: :get do
    render plain: Member.gribouille_emails.to_csv
  end

  member_action :create_invoice, method: :post do
    InvoiceCreator.new(resource).create
    redirect_to invoices_path(q: { member_id_eq: resource.id }, scope: :all)
  end

  controller do
    def scoped_collection
      Member.includes(
        :first_membership,
        :current_year_memberships,
        current_membership: [:basket, :distribution]
      )
    end

    def apply_sorting(chain)
      params[:order] ||= 'waiting_started_at_asc' if params[:scope] == 'waiting'
      super
    end

    def find_resource
      Member.find_by(token: params[:id])
    end

    def create_resource(object)
      run_create_callbacks object do
        object.validated_at = Time.zone.now
        object.validator = current_admin
        save_resource(object)
      end
    end
  end

  config.per_page = 25
  config.sort_order = 'last_name_asc'
  config.batch_actions = true
end
