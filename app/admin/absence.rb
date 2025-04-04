# frozen_string_literal: true

ActiveAdmin.register Absence do
  menu parent: :other, priority: 1

  breadcrumb do
    if params[:action] == "new"
      [ link_to(Absence.model_name.human(count: 2), absences_path) ]
    elsif params["action"] != "index"
      links = [
        link_to(Member.model_name.human(count: 2), members_path),
        auto_link(resource.member),
        link_to(
          Absence.model_name.human(count: 2),
          absences_path(q: { member_id_eq: resource.member_id }, scope: :all))
      ]
      if params["action"].in? %W[edit]
        links << auto_link(resource)
      end
      links
    end
  end

  scope :all, default: true
  scope :past
  scope :current
  scope :future

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :including_date,
    as: :select,
    collection: -> { Delivery.reorder(date: :desc).map { |d| [ d.display_name, d.date ] } },
    label: -> { Delivery.model_name.human }
  filter :member,
    as: :select,
    collection: -> { Member.joins(:absences).order_by_name.distinct }
  filter :with_note, as: :boolean

  includes :member, :session, :baskets
  index do
    column :member, ->(absence) {
      with_note_icon absence.note do
        link_with_session absence.member, absence.session
      end
    }, sortable: "members.name"
    column :started_on, ->(absence) {
      link_to l(absence.started_on, format: :short), absence
    }, class: "text-right"
    column :ended_on, ->(absence) {
      link_to l(absence.ended_on, format: :short), absence
    }, class: "text-right"
    column :deliveries, ->(absence) {
      link_to absence.baskets.size, absence
    }, class: "text-right"
    actions
  end

  sidebar_handbook_link("absences")

  show do |absence|
    columns do
      column do
        panel Basket.model_name.human(count: 2), count: absence.baskets.count do
          table_for absence.baskets.includes(:membership, :delivery), class: "table-auto" do
            column(:delivery) { |b| auto_link(b.delivery) }
            column(:membership) { |b| auto_link(b.membership) }
          end
        end
      end
      column do
        panel t(".details") do
          attributes_table do
            row :id
            row :member
            row(:email_session) { absence.session&.email }
            row :note
            row(:started_on) { l absence.started_on }
            row(:ended_on) { l absence.ended_on }
          end
        end
        active_admin_comments_for(absence)
      end
    end
  end

  form do |f|
    f.inputs t(".details") do
      f.input :member,
        collection: Member.joins(:memberships).distinct.order_by_name.map { |d| [ d.name, d.id ] },
        prompt: true
      div class: "single-line" do
        f.input :started_on, as: :date_picker
        f.input :ended_on, as: :date_picker
      end
      if f.object.persisted?
        f.input :note, as: :text, input_html: { rows: 4 }
      else
        f.input :comment, as: :text, input_html: { rows: 4 }
      end
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
        namespace: "root")
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper

    def apply_sorting(chain)
      super(chain).joins(:member).merge(Member.order_by_name)
    end
  end

  order_by("members.name") do |clause|
    Member
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "started_on_desc"
end
