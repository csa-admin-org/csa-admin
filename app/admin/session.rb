# frozen_string_literal: true

ActiveAdmin.register Session, as: "MSession" do
  menu label: -> { Session.model_name.human(count: 2) }, parent: :other, priority: 99
  actions :index

  scope :all
  scope :recent, default: true
  scope :active
  scope :expired

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
    column nil, ->(s) {
      content_tag(:span, class: "flex items-center gap-1 justify-end text-gray-500") {
        txt = ""
        txt += icon("arrow-right-start-on-rectangle", class: "h-5 w-5") if s.revoked?
        txt += icon("archive-box-x-mark", class: "h-5 w-5") if s.expired?
        txt += icon("key", class: "h-5 w-5") if s.admin
        txt += icon("user", class: "h-5 w-5") if s.member
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
