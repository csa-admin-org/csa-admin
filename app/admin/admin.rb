# frozen_string_literal: true

ActiveAdmin.register Admin do
  menu parent: :other, priority: 2
  actions :all, except: [ :show ]

  filter :name_cont, label: -> { Admin.human_attribute_name(:name) }
  filter :email_cont, label: -> { Admin.human_attribute_name(:email) }
  filter :permission

  includes :last_session, :permission
  index download_links: false do
    column :name
    column :email, ->(admin) { display_email_with_link(self, admin.email) }
    column :permission, ->(a) {
      link_to a.permission&.name, permissions_path
    }
    column :last_session_used_at, ->(a) {
      if a.last_session_used_at
        link_to_if authorized?(:read, Session),
          I18n.l(a.last_session_used_at, format: :short),
          m_sessions_path(q: { owner_type_eq: "Admin", admin_id_eq: a.id }, scope: :all)
      end
    }, class: "text-right tabular-nums"
    if Tenant.demo? && current_admin.ultra?
      column t("admin.demo_page_visits.visits"), ->(a) {
        count = a.demo_page_visits_count
        link_to_if count.positive?, count, demo_page_visits_path(q: { admin_id_eq: a.id })
      }, class: "text-right tabular-nums"
    end
    actions
  end

  action_item :permissions, only: :index do
    action_link Permission.model_name.human(count: 2), permissions_path, icon: "key"
  end

  action_item :invite, only: :edit, if: -> {
    authorized?(:invite, resource) && resource != current_admin && resource.can_resend_invitation?
  } do
    action_button t("active_admin.shared.action_items.resend_invitation"),
      invite_admin_path(resource),
      icon: "mail",
      data: { confirm: t("active_admin.shared.action_items.resend_invitation_confirm") }
  end

  form do |f|
    if f.object.new_record?
      para t(".admin_invitation"), class: "description is-tight text-base"
    end
    f.inputs t(".details"), icon: "notebook-text" do
      f.input :name
      f.input :email
      f.input :language,
        as: :select,
        collection: org_languages_collection,
        prompt: true,
        wrapper_html: { id: "languages", class: "settings-anchor" }
      if f.object.persisted? && f.object == current_admin
        li id: "theme", class: "input settings-anchor" do
          render partial: "shared/icon_select", locals: {
            name: "admin[theme]",
            value: f.object.theme,
            options: theme_icon_select_options,
            label_text: Admin.human_attribute_name(:theme),
            required: true
          }
        end
      end
      if authorized?(:manage, Admin) && f.object != current_admin
        f.input :permission, collection: Permission.all, prompt: true, include_blank: false
      end
    end
    f.inputs id: "notifications" do
      f.input :notifications,
        as: :check_boxes,
        wrapper_html: { class: "legend-title single-column" },
        collection: Admin.notifications.map { |n|
          [
            content_tag(:span) {
              content_tag(:h3, t("admin.notifications.#{n}"), class: "font-medium") +
              content_tag(:span, t("admin.notifications.#{n}_hint").html_safe, class: "is-muted")
            },
            n
          ]
        }.sort_by(&:first)
    end
    f.actions
  end

  permit_params do
    pp = %i[name email language theme]
    pp << :permission_id if authorized?(:manage, Admin)
    pp << { notifications: [] }
    pp
  end

  after_create do |admin|
    if admin.persisted?
      AdminMailer.with(
        admin: admin,
        action_url: root_url
      ).invitation_email.deliver_later
    end
  end

  member_action :invite, method: :post do
    authorize!(:invite, resource)
    raise ActiveAdmin::AccessDenied unless resource != current_admin && resource.can_resend_invitation?

    AdminMailer.with(
      admin: resource,
      action_url: root_url
    ).invitation_email.deliver_later
    redirect_to admins_path, notice: t("active_admin.shared.action_items.resend_invitation_notice")
  end

  controller do
    def scoped_collection
      collection = end_of_association_chain

      # Hide ultra admin from non-ultra admins
      if (ultra_email = ENV["ULTRA_ADMIN_EMAIL"])
        collection = collection.where.not(email: ultra_email)
      end

      # In demo mode, non-ultra admins only see themselves
      if Tenant.demo? && !current_admin.ultra?
        collection = collection.where(id: current_admin.id)
      end

      collection
    end

    def find_resource
      Admin.find(params[:id])
    end
  end

  order_by("name") do |clause|
    config
      .resource_class
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "name_asc"
end
