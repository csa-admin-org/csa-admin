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

  filter :member,
    as: :select,
    collection: -> { Member.joins(:absences).order(:name).distinct }
  filter :with_note, as: :boolean
  filter :including_date,
    as: :select,
    collection: -> { Delivery.reorder(date: :desc).map { |d| [d.display_name, d.date] } },
    label: -> { Delivery.model_name.human }
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :member, :session
  index do
    column :member, ->(absence) {
      with_note_icon absence.note do
        link_with_session absence.member, absence.session
      end
    }, sortable: 'members.name'
    column :started_on, ->(absence) { l absence.started_on }
    column :ended_on, ->(absence) { l absence.ended_on }
    actions class: 'col-actions-3'
  end

  show do |absence|
    attributes_table do
      row :id
      row :member
      row(:email_session) { absence.session&.email }
      row :note
      row(:started_on) { l absence.started_on }
      row(:ended_on) { l absence.ended_on }
    end

    active_admin_comments
  end

  form do |f|
    f.inputs t('.details') do
      f.input :member,
        collection: Member.joins(:memberships).distinct.order(:name).map { |d| [d.name, d.id] },
        prompt: true
      if f.object.persisted?
        f.input :note, as: :text, input_html: { rows: 4 }
      else
        f.input :comment, as: :text, input_html: { rows: 4 }
      end
    end
    f.inputs Absence.human_attribute_name(:dates) do
      f.input :started_on, as: :date_picker
      f.input :ended_on, as: :date_picker
    end
    f.actions
  end

  permit_params(*%i[member_id started_on ended_on note comment])

  before_build do |absence|
    absence.started_on ||= Date.current.next_week
    absence.ended_on ||= Date.current.next_week.end_of_week
    absence.member_id ||= referer_filter(:member_id)
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
    include ApplicationHelper

    def apply_sorting(chain)
      super(chain).joins(:member).order('members.name', id: :desc)
    end

    def create
      create! do |success, failure|
        success.html { redirect_to collection_url }
      end
    end

    def update
      update! do |success, failure|
        success.html { redirect_to collection_url }
      end
    end
  end

  config.sort_order = 'started_on_desc'
end
