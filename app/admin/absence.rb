ActiveAdmin.register Absence do
  menu parent: :other, priority: 1

  breadcrumb do
    if params[:action] == 'new'
      [link_to(Absence.model_name.human(count: 2), absences_path)]
    elsif params['action'] != 'index'
      links = [
        link_to(Member.model_name.human(count: 2), members_path),
        auto_link(absence.member),
        link_to(
          Absence.model_name.human(count: 2),
          absences_path(q: { member_id_eq: absence.member_id }, scope: :all))
      ]
      if params['action'].in? %W[edit]
        links << auto_link(absence)
      end
      links
    end
  end

  scope :all, default: true
  scope :past
  scope :current
  scope :future

  includes :member, :session
  index do
    column :member, ->(absence) {
      link_with_session absence.member, absence.session
    }, sortable: 'members.name'
    column :started_on, ->(absence) { l absence.started_on }
    column :ended_on, ->(absence) { l absence.ended_on }
    actions class: 'col-actions-3'
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:absences).order(:name).distinct }
  filter :including_date,
    as: :select,
    collection: -> { Delivery.reorder(date: :desc).map { |d| [d.display_name, d.date] } },
    label: -> { Delivery.model_name.human }
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

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
        f.input :comment, as: :text, input_html: { rows: 4 }
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

  before_update do |absence|
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

  controller do
    include TranslatedCSVFilename

    def apply_sorting(chain)
      super(chain).joins(:member).order('members.name')
    end
  end

  config.per_page = 25
  config.sort_order = 'started_on_desc'
end
