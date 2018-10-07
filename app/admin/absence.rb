ActiveAdmin.register Absence do
  menu parent: :other, priority: 1

  scope :all, default: true
  scope :past
  scope :current
  scope :future

  includes :member
  index do
    column :member, ->(absence) {
      link_with_session absence.member, absence.session
    }, sortable: 'members.name'
    column :started_on, ->(absence) { l absence.started_on }
    column :ended_on, ->(absence) { l absence.ended_on }
    actions
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:absences).order(:name).distinct }
  filter :including_date,
    as: :select,
    collection: -> { Delivery.all.map { |d| [d.display_name, d.date] } },
    label: -> { Delivery.model_name.human }

  show do |absence|
    attributes_table do
      row :id
      row :member
      row(:email) { absence.session&.email }
      row(:started_on) { l absence.started_on }
      row(:ended_on) { l absence.ended_on }
    end

    active_admin_comments
  end

  form do |f|
    f.inputs Member.model_name.human do
      f.input :member,
        collection: Member.joins(:memberships).distinct.order(:name).map { |d| [d.name, d.id] },
        prompt: true
    end
    f.inputs Absence.human_attribute_name(:dates) do
      f.input :started_on, as: :datepicker
      f.input :ended_on, as: :datepicker
    end
    unless f.object.persisted?
      f.inputs Absence.human_attribute_name(:comment) do
        f.input :comment, as: :text
      end
    end

    f.actions
  end

  permit_params(*%i[member_id started_on ended_on comment])

  before_build do |absence|
    absence.started_on ||= Date.current.next_week
    absence.ended_on ||= Date.current.next_week.end_of_week
    absence.admin = current_admin
  end

  after_create do |absence|
    if absence.persisted? && absence.comment.present?
      ActiveAdmin::Comment.create!(
        resource: absence,
        body: absence.comment,
        author: current_admin,
        namespace: 'root')
    end
  end

  config.per_page = 25
end
