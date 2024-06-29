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
    column :owner, ->(s) { auto_link(s.owner) }
    column :browser, ->(s) { s.last_user_agent&.to_s }
    column :os, ->(s) { s.last_user_agent&.os&.to_s }
    column :device, ->(s) { s.last_user_agent&.device&.model }
    column :last_used_at, ->(s) { l(s.last_used_at, format: :medium) if s.last_used_at }, class: "text-right whitespace-nowrap"
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
