ActiveAdmin.register HalfdayParticipation do
  menu priority: 6

  scope :pending, default: true
  scope :coming
  scope :validated
  scope :rejected

  index_title = -> { "½ Journées (#{I18n.t("active_admin.scopes.#{current_scope.name.gsub(' ', '_').downcase}").downcase})" }

  index title: index_title do
    selectable_column
    column :member, sortable: 'members.last_name'
    column 'Date', ->(hp) { l hp.halfday.date, format: :medium }, sortable: 'halfdays.date'
    column 'Horaire', ->(hp) { hp.halfday.period }
    column 'Lieu', ->(hp) { display_place(hp.halfday) }
    column 'Activité', ->(hp) { hp.halfday.activity }
    column 'Part.', :participants_count
    column :state, ->(hp) { I18n.t("halfday_participation.state.#{hp.state}") }
    actions
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:halfday_participations).order(:last_name).distinct }

  form do |f|
    f.inputs 'Details' do
      f.input :halfday,
        collection: Halfday.order(date: :desc),
        include_blank: false
      f.input :member,
        collection: Member.valid_for_memberships.order(:last_name).distinct,
        include_blank: false
      f.input :participants_count
    end
    f.actions
  end

  permit_params *%i[halfday_id member_id participants_count]

  batch_action :reject do |selection|
    HalfdayParticipation.find(selection).each do |participation|
      participation.reject!(current_admin)
    end
    redirect_to collection_path
  end

  batch_action :validate do |selection|
    HalfdayParticipation.find(selection).each do |participation|
      participation.validate!(current_admin)
    end
    redirect_to collection_path
  end

  controller do
    def scoped_collection
      HalfdayParticipation.includes(:member, :halfday)
    end

    before_create do |participation|
      if participation.halfday.date.past?
        participation.validated_at = Time.zone.now
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
  config.sort_order = 'created_at_desc'
  config.batch_actions = true
end
