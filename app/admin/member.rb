ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :pending
  scope :waiting
  scope :trial
  scope :active, default: true
  scope :support
  scope :inactive

  index_title = -> { "Membres (#{I18n.t("active_admin.scopes.#{current_scope.name.gsub(' ', '_').downcase}").downcase})" }

  index title: index_title do
    selectable_column
    if params[:scope] == 'waiting'
      @waiting_started_ats ||= Member.waiting.order(:waiting_started_at).pluck(:waiting_started_at)
      column '#', ->(member) {
        str = (@waiting_started_ats.index(member.waiting_started_at) + 1).to_s
        str << '*' if member.waiting_started_at >= Time.utc(2016)
        str
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
      row :address
      row(:city) { member.city? ? "#{member.city} (#{member.zip})" : nil }
      row :phones
      row :emails
      row(:gribouille) { member.gribouille? ? 'envoyée' : 'non-envoyée' }
      row :current_membership do
        if member.current_membership
          link_to "#{member.basket.name} / #{member.distribution.name}", member.current_membership
        end
      end
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
      row :created_at
      row :validated_at
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

  form do |f|
    f.inputs 'Details' do
      f.input :first_name
      f.input :last_name
      f.input :address
      f.input :city
      f.input :zip
      f.input :emails, hint: "séparés par ', '"
      f.input :phones, hint: "séparés par ', '"
      f.input :gribouille, as: :select,
        collection: [['envoyée', true], ['non-envoyée', false]],
        hint: 'laisser blanc, pour le comportement par défault (en fonction du status)'
      f.input :billing_interval,
        collection: Member::BILLING_INERVALS.map { |i| [I18n.t("member.billing_interval.#{i}"), i] },
        include_blank: false
      f.input :support_member
      f.input :salary_basket, hint: 'Abonnement(s) gratuit(s)'
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
    support_member salary_basket billing_interval waiting
    waiting_basket_id waiting_distribution_id
    food_note note
  ]

  batch_action :validate do |selection|
    Member.find(selection).each do |member|
      member.validate!(current_admin)
    end
    redirect_to collection_path
  end

  collection_action :gribouille_emails, method: :get do
    render text: Member.gribouille_emails.to_csv
  end

  controller do
    def scoped_collection
      Member.includes(current_membership: [:basket, :distribution])
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
        object.validated_at = Time.now
        object.validator = current_admin
        save_resource(object)
      end
    end
  end

  config.per_page = 150
  config.sort_order = 'last_name_asc'
  config.batch_actions = true
end
