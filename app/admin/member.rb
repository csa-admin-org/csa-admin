ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :waiting_validation
  scope :waiting_list
  scope :active, default: true
  scope :support
  scope :inactive


  index do
    selectable_column
    if params[:scope] == 'waiting_list'
      @waiting_froms ||= Member.waiting_list.order(:waiting_from).pluck(:waiting_from)
      column '#', ->(member) { @waiting_froms.index(member.waiting_from) + 1 }, sortable: :waiting_from
    end
    column :name, ->(member) { link_to member.name, member }, sortable: :last_name
    column :city, ->(member) { member.city? ? "#{member.city} (#{member.zip})" : nil }
    column :current_membership do |member|
      if member.current_membership
        link_to "#{member.current_basket.name} (#{member.current_distribution.name})", member.current_membership
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
      row :current_membership do
        if member.current_membership
          link_to "#{member.current_basket.name} (#{member.current_distribution.name})", member.current_membership
        end
      end
      row(:status) { I18n.t("member.status.#{member.status}") }
      row :food_note
      row :note
      row :created_at
      row :waiting_from
      row :validated_at
      row :validator
    end
  end

  filter :with_name, as: :string
  filter :address
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
    end
    f.inputs 'Abonnement' do
      if f.object.new_record?
        f.input :support_member
        f.semantic_fields_for :membership do |m_f|
          m_f.input :basket_id, label: 'Panier',
            collection: options_for_select(
              Basket.all.map { |b| [b.name, b.id] },
              f.object.memberships.first.try(:basket_id)
            )
          m_f.input :distribution_id,
            collection: options_for_select(
              Distribution.all.map { |d| [d.name, d.id] },
              f.object.memberships.first.try(:distribution_id)
            )
        end
        f.input :billing_interval,
          collection: Member::BILLING_INERVALS.map { |i| [I18n.t("member.billing_interval.#{i}"), i] },
          include_blank: false
        f.input :waiting_list, as: :boolean
      else
        f.input :support_member
        f.input :billing_interval,
          collection: Member::BILLING_INERVALS.map { |i| [I18n.t("member.billing_interval.#{i}"), i] },
          include_blank: false
        f.input :waiting_list, as: :boolean
      end
    end
    f.inputs 'Notes' do
      f.input :food_note, input_html: { rows: 3 }
      f.input :note, input_html: { rows: 3 }
    end
    f.actions
  end

  batch_action :validate do |selection|
    Member.find(selection).each do |member|
      member.validate!(current_admin)
    end
    redirect_to collection_path
  end

  permit_params do
    %i[
      first_name last_name address city zip emails phones
      support_member billing_interval waiting_list
      food_note note
    ].concat([membership: %i[basket_id distribution_id]])
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
