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
      content_tag(:span, class: "flex items-center gap-1 justify-end text-gray-500") {
        txt = ""
        txt += icon("log-out", class: "size-5") if s.revoked?
        txt += icon("archive-x", class: "size-5") if s.expired?
        txt += icon("key", class: "size-5") if s.admin
        txt += icon("user", class: "size-5") if s.member
        txt.html_safe
      }
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
