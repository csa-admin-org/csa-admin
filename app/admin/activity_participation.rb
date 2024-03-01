ActiveAdmin.register ActivityParticipation do
  menu parent: :activities_human_name, priority: 1

  breadcrumb do
    links = [ activities_human_name ]
    if params[:action] == "new"
      links << link_to(ActivityParticipation.model_name.human(count: 2), activity_participations_path)
    elsif params["action"] != "index"
      links << link_to(Activity.model_name.human(count: 2), activities_path)
      links << auto_link(activity_participation.activity)
      links << link_to(
        ActivityParticipation.model_name.human(count: 2),
        activity_participations_path(q: { activity_id_eq: activity_participation.activity_id }, scope: :all))
      if params["action"].in? %W[edit]
        links << auto_link(activity_participation)
      end
    end
    links
  end

  scope :all
  scope :future
  scope :pending, default: true
  scope :validated
  scope :rejected

  filter :member,
    as: :select,
    collection: -> { Member.joins(:activity_participations).order(:name).distinct }
  filter :with_note, as: :boolean
  filter :activity,
    as: :select,
    collection: -> { Activity.order(date: :desc, start_time: :desc) }
  filter :activity_date, label: -> { Activity.human_attribute_name(:date) }, as: :date_range
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :member, :activity, :session
  index do
    selectable_column
    column :member, ->(ap) {
      with_note_icon ap.note do
        link_with_session ap.member, ap.session
      end
    }, sortable: "members.name"
    column :activity, ->(ap) {
      link_to ap.activity.name(show_place: false), activity_participations_path(q: { activity_id_eq: ap.activity_id }, scope: :all)
    }, sortable: "activities.date"
    column :participants_short, ->(ap) {
      ap.participants_count
    }, sortable: "participants_count", class: "align-right"
    column :state, ->(ap) { status_tag ap.state }
    actions class: "col-actions-3"
  end

  csv do
    column(:activity) { |ap| ap.activity.name }
    column(:member_id, &:member_id)
    column(:member_name) { |ap| ap.member.name }
    column(:member_phones) { |ap|
      ap.member.phones_array.map { |p| display_phone(p) }.join(", ")
    }
    column(:member_emails) { |ap| ap.member.emails_array.join(", ") }
    column(:email_session) { |ap| ap.session&.email }
    column(:note)
    column(:participants_count)
    column(:carpooling_phone) { |ap| ap.carpooling_phone&.phony_formatted }
    column(:carpooling_city, &:carpooling_city)
    column(:state, &:state_i18n_name)
    column(:latest_reminder_sent_at)
    column(:created_at)
    column(:validated_at)
    column(:rejected_at)
  end

  sidebar :total, only: :index do
    all = collection.unscope(:includes).offset(nil).limit(nil)
    div class: "content" do
      div class: "total" do
        span activities_human_name + ":"
        span all.sum(:participants_count), style: "float: right; font-weight: bold;"
      end
    end
  end

  sidebar :billing, only: :index, if: -> { Current.acp.activity_price.positive? } do
    div class: "actions" do
      handbook_icon_link("billing", anchor: "activity")
    end

    div class: "content" do
      no_counts = true
      [ Current.fy_year - 1, Current.fy_year ].each do |year|
        fy = Current.acp.fiscal_year_for(year)
        missing_count = Membership.during_year(fy).sum(&:missing_activity_participations)
        if missing_count.positive?
          no_counts = false
          div class: "top-spacing" do
            span t(".missing_activity_participations_count_html", year: fy.to_s, count: missing_count)
          end
          if authorized?(:invoice_all, ActivityParticipation)
            div class: "top-small-spacing" do
              button_to t(".invoice_all"), invoice_all_activity_participations_path,
                params: { year: fy.year },
                form: { data: { controller: "disable", disable_with_value: t(".invoicing") } },
                data: { confirm: t(".invoice_all_confirm", year: fy.to_s, count: missing_count, activity_price: cur(Current.acp.activity_price)) },
                class: "full-width"
            end
          end
        end
      end
      if no_counts
        div class: "content" do
          span t(".no_missing_activity_participations"), class: "empty"
        end
      end
    end
  end

  collection_action :invoice_all, method: :post do
    authorize!(:invoice_all, ActivityParticipation)
    ActivityParticipation.invoice_all_missing(params[:year])
    redirect_to collection_path, notice: t("active_admin.resource.index.invoicing")
  end

  sidebar :calendar, if: -> { Current.acp.icalendar_auth_token? }, only: :index do
    div class: "content" do
      para t(".activity_participation_ical_text_html")
      div do
        link_to t(".subscribe_ical_link"), activity_participations_calendar_url(auth_token: Current.acp.icalendar_auth_token).gsub(/^https/, "webcal"),
          data: { turbolinks: false },
          class: "button full-width"
      end
    end
  end

  sidebar_handbook_link("activity#participations")

  form do |f|
    f.inputs t(".details") do
      f.input :activity,
        collection: Activity.order(date: :desc),
        prompt: true
      f.input :member,
        collection: Member.order(:name).distinct,
        prompt: true
      f.input :participants_count
      if f.object.persisted?
        f.input :note, as: :text, input_html: { rows: 4 }
      else
        f.input :comment, as: :text, input_html: { rows: 4 }
      end
    end
    f.actions
  end

  permit_params(*%i[activity_id member_id participants_count note comment])

  show do |ap|
    columns do
      column do
        attributes_table title: ActivityParticipation.human_attribute_name(:contact) do
          row :member
          row(:email) { display_emails_with_link(self, ap.emails) }
          row(:phones) { display_phones_with_link(self, ap.member.phones_array) }
          if ap.carpooling?
            row(:carpooling_phone) { display_phones_with_link(self, ap.carpooling_phone) }
            row(:carpooling_city) { ap.carpooling_city }
          end
        end

        if ap.invoices.any?
          attributes_table title: t(".billing") do
            row(:invoiced_at) { auto_link ap.invoices.first, l(ap.invoices.first.date) }
          end
        end
      end
      column do
        attributes_table do
          row(:activity) { link_to ap.activity.name, activity_participations_path(q: { activity_id_eq: ap.activity_id }, scope: :all) }
          row(:participants_count)
          row(:latest_reminder_sent_at) { l(ap.latest_reminder_sent_at, format: :long) if ap.latest_reminder_sent_at }
          row(:created_at)  { l(ap.created_at, format: :long) }
          row(:updated_at) { l(ap.updated_at, format: :long) }
        end


        if ap.validated? || ap.rejected?
          attributes_table title: ActivityParticipation.human_attribute_name(:state) do
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

        active_admin_comments
      end
    end
  end

  batch_action :validate, if: ->(_) {
    authorized?(:update, ActivityParticipation) &&
      params[:scope].in?([ nil, "pending", "rejected" ])
  } do |selection|
    participations = ActivityParticipation.includes(:activity).where(id: selection)
    participations.find_each do |participation|
      participation.validate!(current_admin)
    end
    if participations.future.any?
      flash[:alert] = t(".validate.flash.alert")
    end
    redirect_back fallback_location: collection_path
  end

  batch_action :reject, if: ->(_) {
    authorized?(:update, ActivityParticipation) &&
      params[:scope].in?([ nil, "pending", "validated" ])
  } do |selection|
    participations = ActivityParticipation.includes(:activity).where(id: selection)
    participations.find_each do |participation|
      participation.reject!(current_admin)
    end
    if participations.future.any?
      flash[:alert] = t(".reject.flash.alert")
    end
    redirect_back fallback_location: collection_path
  end

  action_item :invoice, only: :show, if: -> {
    authorized?(:create, Invoice) && resource.rejected? && resource.invoices.none?
  } do
    link_to t(".invoice_action"),
      new_invoice_path(activity_participation_id: resource.id, anchor: "activity_participation")
  end

  before_build do |ap|
    ap.session_id ||= session_id
    ap.member_id ||= referer_filter(:member_id)
    ap.activity_id ||= referer_filter(:activity_id)
  end

  after_create do |ap|
    if ap.persisted? && ap.comment.present?
      ActiveAdmin::Comment.create!(
        resource: ap,
        body: ap.comment,
        author: current_admin,
        namespace: "root")
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper

    def apply_sorting(chain)
      if params[:scope].in?(%w[validated rejected]) && !params[:order]
        super(chain).joins(:member).reorder("activities.date DESC, members.name", id: :desc)
      else
        super(chain).joins(:member).order("members.name", id: :desc)
      end
    end

    before_create do |participation|
      if participation.activity.date.past?
        participation.validated_at = Time.current
        participation.validator = current_admin
      end
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

  config.sort_order = "activities.date_asc"
  config.batch_actions = true
end
