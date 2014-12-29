ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :waiting_validation
  scope :waiting_list
  scope :active, default: true
  scope :support
  scope :inactive

  index_title = -> { "Membres (#{I18n.t("active_admin.scopes.#{current_scope.name.gsub(' ', '_').downcase}").downcase})" }

  index title: index_title do
    selectable_column
    if params[:scope] == 'waiting_list'
      @waiting_froms ||= Member.waiting_list.order(:waiting_from).pluck(:waiting_from)
      column '#', ->(member) { @waiting_froms.index(member.waiting_from) + 1 }, sortable: :waiting_from
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
    column :status, ->(member) { I18n.t("member.status.#{member.status}") }
    actions
  end

  show do |member|
    attributes_table do
      row :id
      row :name
      row :address
      row(:city) { member.city? ? "#{member.city} (#{member.zip})" : nil }
      row :emails
      row :phones
      row(:gribouille) { member.gribouille? ? 'envoyée' : 'non-envoyée' }
      row :current_membership do
        if member.current_membership
          link_to "#{member.basket.name} / #{member.distribution.name}", member.current_membership
        end
      end
      row(:status) { I18n.t("member.status.#{member.status}") }
      row :food_note
      row :note
      row :created_at
      row :waiting_from
      if member.status.in? %i[waiting_validation waiting_list]
        row :waiting_basket
        row :waiting_distribution
      end
      row :validated_at
      row :validator
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
      f.input :gribouille, label: 'Gribouille (toujours envoyée aux membres actifs)'
      f.input :billing_interval,
        collection: Member::BILLING_INERVALS.map { |i| [I18n.t("member.billing_interval.#{i}"), i] },
        include_blank: false
      f.input :support_member
    end
    f.inputs 'Notes' do
      f.input :food_note, input_html: { rows: 3 }
      f.input :note, input_html: { rows: 3 }
    end
    if member.new_record? || member.waiting_from_changed? || member.status.in?(%i[waiting_validation waiting_list])
      f.inputs "Abonnement" do
        f.input :waiting_list, as: :boolean
        f.input :waiting_basket, label: 'Panier'
        f.input :waiting_distribution, label: 'Distribution'
      end
    end
    f.actions
  end

  permit_params %i[
    first_name last_name address city zip emails phones gribouille
    support_member billing_interval waiting_list
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
      params[:order] ||= 'waiting_from_asc' if params[:scope] == 'waiting_list'
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
