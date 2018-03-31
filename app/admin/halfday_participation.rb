ActiveAdmin.register HalfdayParticipation do
  menu parent: :halfdays_human_name, priority: 1, label: 'Participations'

  scope :all
  scope :pending, default: true
  scope :coming
  scope :validated
  scope :rejected

  includes :member, :halfday
  index do
    selectable_column
    column :member, sortable: 'members.name'
    column :halfday, ->(hp) {
      link_to hp.halfday.name, halfday_participations_path(q: { halfday_id_eq: hp.halfday_id }, scope: :all)
    }, sortable: 'halfdays.date, halfdays.start_time'
    column 'Part.', :participants_count
    column :state, ->(hp) { status_tag(hp.state) }
    actions
  end

  csv do
    column(:date) { |hp| hp.halfday.date.to_s }
    column('ID Membre') { |hp| hp.member_id }
    column('Nom Membre') { |hp| hp.member.name }
    column(:participants_count)
    column(:carpooling_phone) { |hp| hp.carpooling_phone&.phony_formatted }
    column(:state)
    column(:created_at)
    column(:validated_at)
    column(:rejected_at)
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:halfday_participations).order(:name).distinct }
  filter :halfday,
    as: :select,
    collection: -> { Halfday.order(:date, :start_time) }
  filter :halfday_date, label: 'Date', as: :date_range

  form do |f|
    f.inputs 'Details' do
      f.input :halfday,
        collection: Halfday.order(date: :desc),
        include_blank: false
      f.input :member,
        collection: Member.order(:name).distinct,
        include_blank: false
      f.input :participants_count
    end
    f.actions
  end

  permit_params *%i[halfday_id member_id participants_count]

  show do |hp|
    attributes_table title: 'Détails' do
      row(:halfday) { link_to hp.halfday.name, halfday_participations_path(q: { halfday_id_eq: hp.halfday_id }, scope: :all) }
      row(:created_at) { l(hp.created_at) }
      row(:updated_at) { l(hp.updated_at) }
    end

    attributes_table title: 'Contact' do
      row :member
      row(:phones) { display_phones(hp.member.phones_array) }
      if hp.carpooling_phone?
        row(:carpooling_phone) { display_phones(hp.carpooling_phone) }
      end
    end

    if hp.validated? || hp.rejected?
      attributes_table title: 'Statut' do
        row(:status) { status_tag hp.state }
        row :validator
        if hp.validated?
          row(:validated_at) { l(hp.validated_at) }
        end
        if hp.rejected?
          row(:rejected_at) { l(hp.rejected_at) }
        end
      end
    end

    active_admin_comments
  end

  batch_action :reject do |selection|
    participations = HalfdayParticipation.includes(:halfday).where(id: selection)
    participations.find_each do |participation|
      participation.reject!(current_admin)
    end
    if participations.coming.any?
      flash[:alert] = t('flash.alert.coming_halfday_participations_cannot_be_rejected')
    end
    redirect_back fallback_location: collection_path
  end

  batch_action :validate do |selection|
    participations = HalfdayParticipation.includes(:halfday).where(id: selection)
    participations.find_each do |participation|
      participation.validate!(current_admin)
    end
    if participations.coming.any?
      flash[:alert] = t('flash.alert.coming_halfday_participations_cannot_be_validated')
    end
    redirect_back fallback_location: collection_path
  end

  controller do
    before_create do |participation|
      if participation.halfday.date.past?
        participation.validated_at = Time.current
        participation.validator = current_admin
      end
    end

    def create
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end

    def update
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end
  end

  config.per_page = 25
  config.sort_order = 'halfdays.date_asc'
  config.batch_actions = true
end
