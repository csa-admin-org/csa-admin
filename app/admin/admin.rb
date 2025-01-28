# frozen_string_literal: true

ActiveAdmin.register Admin do
  menu parent: :other, priority: 2
  actions :all, except: [ :show ]

  filter :name
  filter :email
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
          I18n.l(a.last_session_used_at, format: :medium),
          m_sessions_path(q: { owner_type_eq: "Admin", admin_id_eq: a.id }, scope: :all)
      end
    }, class: "text-right"
    actions
  end

  action_item :permissions, only: :index do
    link_to Permission.model_name.human(count: 2), permissions_path, class: "action-item-button"
  end

  form do |f|
    if f.object.new_record?
      para t(".admin_invitation"), class: "m-0 pt-0 pb-4 text-base"
    end
    f.inputs t(".details") do
      f.input :name
      f.input :email
      f.input :language,
        as: :select,
        collection: Organization.languages.map { |l| [ t("languages.#{l}"), l ] },
        prompt: true
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
            content_tag(:span, class: "ms-1") {
              content_tag(:h3, t("admin.notifications.#{n}"), class: "font-medium") +
              content_tag(:span, t("admin.notifications.#{n}_hint").html_safe, class: "text-gray-500 dark:text-gray-400")
            },
            n
          ]
        }.sort_by(&:first)
    end
    f.actions
  end

  permit_params do
    pp = %i[name email language]
    pp << :permission_id if authorized?(:manage, Admin)
    pp << { notifications: [] }
    pp
  end

  after_create do |admin|
    AdminMailer.with(
      admin: admin,
      action_url: root_url
    ).invitation_email.deliver_later
  end

  controller do
    def scoped_collection
      if master_email = ENV["MASTER_ADMIN_EMAIL"]
        end_of_association_chain.where.not(email: master_email)
      else
        super
      end
    end

    def find_resource
      Admin.find(params[:id])
    end
  end

  config.sort_order = "name_asc"
end
