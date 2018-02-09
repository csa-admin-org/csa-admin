ActiveAdmin.register Absence do
  menu parent: 'Autre', priority: 1

  scope :all, default: true
  scope :past
  scope :current
  scope :future

  includes :member
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
    collection: -> { Member.joins(:absences).order(:name).distinct }
  filter :including_date,
    as: :select,
    collection: -> { Delivery.all.map { |d| ["Panier ##{d.number} (#{d.date})", d.date] } },
    label: 'Incluant'

  show do |absence|
    attributes_table do
      row :id
      row :member
      row(:note) { simple_format absence.note }
      row(:started_on) { l absence.started_on }
      row(:ended_on) { l absence.ended_on }
    end
  end

  form do |f|
    f.inputs 'Membre' do
      f.input :member,
        collection: Member.joins(:memberships).distinct.order(:name).map { |d| [d.name, d.id] },
        include_blank: false
    end
    f.inputs 'Note' do
      f.input :note, input_html: { rows: 5 }
    end
    f.inputs 'Dates' do
      f.input :started_on, as: :datepicker, include_blank: false
      f.input :ended_on, as: :datepicker, include_blank: false
    end

    f.actions
  end

  permit_params *%i[
    member_id started_on ended_on note
  ]

  before_build do |absence|
    absence.started_on ||= Date.current
    absence.ended_on ||= Date.current
  end

  config.per_page = 25
end
