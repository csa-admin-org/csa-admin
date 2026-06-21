# frozen_string_literal: true

ActiveAdmin.register Session, as: "MSession" do
  menu false
  actions :index

  scope :all
  scope :recent, group: :state, default: true
  scope :active, group: :state
  scope :expired, group: :state

  filter :owner_type, as: :select, collection: %w[Admin Member]
  filter :admin
  filter :member
  filter :last_user_agent
  filter :last_used_at
  filter :created_at

  includes :admin, :member
  index download_links: false, title: -> { Session.model_name.human(count: 2) }  do
    column :owner
    column :browser, ->(s) { s.last_user_agent&.to_s }, class: "text-right"
    column :os, ->(s) { s.last_user_agent&.os&.to_s }, class: "text-right"
    column :last_used_at, ->(s) { l(s.last_used_at, format: :short) if s.last_used_at }, class: "text-right whitespace-nowrap"
    if Tenant.demo? && current_admin.ultra?
      column t("admin.demo_page_visits.visits"), ->(s) {
        count = s.demo_page_visits.count
        link_to_if count.positive?, count, demo_page_visits_path(q: { session_id_eq: s.id })
      }, class: "text-right tabular-nums"
    end
    column nil, ->(s) {
      status_icon = ->(key, icon_name, **options) {
        tooltip(
          dom_id(s, key),
          t("active_admin.resources.m_session.status_icons.#{key}", **options),
          icon_name: icon_name,
          icon_class: "size-5")
      }

      icons = []
      icons << status_icon.call(:revoked, "ban") if s.revoked?
      icons << status_icon.call(:expired, "calendar-x") if s.expired?
      if s.admin_originated?
        icons << status_icon.call(:admin_originated, "shield-user", admin: s.admin.name)
      elsif s.admin
        icons << status_icon.call(:admin, "shield-user")
      end
      icons << status_icon.call(:member, "user") if s.member

      content_tag(:span, safe_join(icons), class: "flex items-center gap-1 justify-end text-gray-500")
    }
  end

  controller do
    def scoped_collection
      super.used
    end
  end

  config.sort_order = "last_used_at_desc"
  config.breadcrumb = false
  config.per_page = 50
end
