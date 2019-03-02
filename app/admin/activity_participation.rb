ActiveAdmin.register ActivityParticipation do
  menu parent: :activities_human_name,
    priority: 1,
    label: -> { Activity.human_attribute_name(:participations) }

  scope :all
  scope :pending, default: true
  scope :coming
  scope :validated
  scope :rejected

  includes :member, :activity
  index do
    selectable_column
    column :member, ->(ap) {
      link_with_session ap.member, ap.session
    }, sortable: 'members.name'
    column :activity, ->(ap) {
      link_to ap.activity.name, activity_participations_path(q: { activity_id_eq: ap.activity_id }, scope: :all)
    }, sortable: 'activities.date'
    column :participants_count
    column :state, ->(ap) { status_tag ap.state }
    actions
  end

  csv do
    column(:date) { |ap| ap.activity.date.to_s }
    column(:member_id, &:member_id)
    column(:member_name) { |ap| ap.member.name }
    column(:member_email) { |ap| ap.session&.email }
    column(:member_phones) { |ap| ap.member.phones_array.map(&:phony_formatted).join(', ') }
    column(:participants_count)
    column(:carpooling_phone) { |ap| ap.carpooling_phone&.phony_formatted }
    column(:carpooling_city, &:carpooling_city)
    column(:state, &:state_i18n_name)
    column(:created_at)
    column(:validated_at)
    column(:rejected_at)
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:activity_participations).order(:name).distinct }
  filter :activity,
    as: :select,
    collection: -> { Activity.order(:date, :start_time) }
  filter :activity_date, label: -> { Activity.human_attribute_name(:date) }, as: :date_range

  form do |f|
    f.inputs t('.details') do
      f.input :activity,
        collection: Activity.order(date: :desc),
        prompt: true
      f.input :member,
        collection: Member.order(:name).distinct,
        prompt: true
      f.input :participants_count
    end
    f.actions
  end

  permit_params(*%i[activity_id member_id participants_count])

  show do |ap|
    attributes_table do
      row(:activity) { link_to ap.activity.name, activity_participations_path(q: { activity_id_eq: ap.activity_id }, scope: :all) }
      row(:participants_count)
      row(:created_at) { l(ap.created_at) }
      row(:updated_at) { l(ap.updated_at) }
    end

    attributes_table title: ActivityParticipation.human_attribute_name(:contact) do
      row :member
      row(:email) { ap.session&.email }
      row(:phones) { display_phones(ap.member.phones_array) }
      if ap.carpooling?
        row(:carpooling_phone) { display_phones(ap.carpooling_phone) }
        row(:carpooling_city) { ap.carpooling_city }
      end
    end

    if ap.validated? || ap.rejected?
      attributes_table ActivityParticipation.human_attribute_name(:state) do
        row(:status) { status_tag ap.state, label: ap.state_i18n_name }
        row :validator
        if ap.validated?
          row(:validated_at) { l(ap.validated_at) }
        end
        if ap.rejected?
          row(:rejected_at) { l(ap.rejected_at) }
        end
      end
    end

    if ap.invoices.any?
      attributes_table title: t('.billing') do
        row(:invoiced_at) { auto_link ap.invoices.first, l(ap.invoices.first.date) }
      end
    end

    active_admin_comments
  end

  batch_action :reject do |selection|
    participations = ActivityParticipation.includes(:activity).where(id: selection)
    participations.find_each do |participation|
      participation.reject!(current_admin)
    end
    if participations.coming.any?
      flash[:alert] = t('.reject.flash.alert')
    end
    redirect_back fallback_location: collection_path
  end

  batch_action :validate do |selection|
    participations = ActivityParticipation.includes(:activity).where(id: selection)
    participations.find_each do |participation|
      participation.validate!(current_admin)
    end
    if participations.coming.any?
      flash[:alert] = t('.validate.flash.alert')
    end
    redirect_back fallback_location: collection_path
  end

  action_item :invoice, only: :show, if: -> {
    authorized?(:create, Invoice) && resource.rejected? && resource.invoices.none?
  } do
    link_to t('.invoice_action'),
      new_invoice_path(activity_participation_id: resource.id, anchor: 'activity_participation')
  end

  controller do
    before_create do |participation|
      if participation.activity.date.past?
        participation.validated_at = Time.current
        participation.validator = current_admin
      end
    end

    def create
      super do
        redirect_to collection_url and return if resource.valid?
      end
    end

    def update
      super do
        redirect_to collection_url and return if resource.valid?
      end
    end
  end

  config.per_page = 25
  config.sort_order = 'activities.date_asc'
  config.batch_actions = true
end
