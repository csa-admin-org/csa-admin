# frozen_string_literal: true

module Demo
  ActiveAdmin.register PageVisit do
    menu false
    actions :index

    filter :admin
    filter :session
    filter :page_key
    filter :path
    filter :controller_name
    filter :action_name
    filter :created_at

    includes :admin, :session
    index download_links: false, title: -> { Demo::PageVisit.model_name.human(count: 2) } do
      column :admin
      column :page_key
      column :path
      column :controller_name
      column :action_name
      column :session, ->(visit) {
        link_to visit.session_id, m_sessions_path(q: { id_eq: visit.session_id }, scope: :all)
      }, class: "text-right tabular-nums"
      column :created_at, ->(visit) { l(visit.created_at, format: :short) }, class: "text-right whitespace-nowrap"
    end

    controller do
      def scoped_collection
        if Tenant.demo? && current_admin.ultra?
          super
        else
          super.none
        end
      end
    end

    config.sort_order = "created_at_desc"
    config.breadcrumb = false
    config.batch_actions = false
    config.per_page = 50
  end
end
