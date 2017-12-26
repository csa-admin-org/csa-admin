ActiveAdmin.register Absence do
  menu parent: 'Autre', priority: 1

  scope :all, default: true
  scope :past
  scope :current
  scope :future

  index do
    column :member do |absence|
      link_to absence.member.name, absence.member
    end
    column :note
    column :started_on, ->(absence) { l absence.started_on }
    column :ended_on, ->(absence) { l absence.ended_on }
    actions
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:absences).order(:last_name).distinct }
  filter :including_date,
    as: :select,
    collection: -> { Delivery.all.map { |d| ["Panier ##{d.number} (#{d.date})", d.date] } },
    label: 'Incluant'

  show do |absence|
    attributes_table do
      row :id
      row :member
      row :note
      row(:started_on) { l absence.started_on }
      row(:ended_on) { l absence.ended_on }
    end
  end

  form do |f|
    f.inputs 'Membre' do
      f.input :member,
        collection: Member.valid_for_memberships.order(:last_name).map { |d| [d.name, d.id] },
        include_blank: false
    end
    f.inputs 'Note' do
      f.input :note, input_html: { rows: 5 }
    end
    f.inputs 'Dates' do
      f.input :started_on,
        start_year: Time.zone.today.year,
        end_year: Time.zone.today.year + 1,
        include_blank: false
      f.input :ended_on,
        start_year: Time.zone.today.year,
        end_year: Time.zone.today.year + 1,
        include_blank: false
    end

    f.actions
  end

  permit_params *%i[
    member_id started_on ended_on note
  ]

  controller do
    def build_resource
      super
      resource.started_on ||= Time.zone.today
      resource.ended_on ||= Time.zone.today
      resource
    end

    def scoped_collection
      Absence.includes(:member)
    end
  end

  config.per_page = 25
end
