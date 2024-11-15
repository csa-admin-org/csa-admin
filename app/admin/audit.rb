# frozen_string_literal: true

ActiveAdmin.register Audit do
  belongs_to :member
  actions :index

  breadcrumb do
    links = [
      link_to(Member.model_name.human(count: 2), members_path),
      auto_link(parent)
    ]
    links
  end

  includes :session
  index download_links: false, chlass: "table-auto" do
    column :actor, ->(a) { link_with_session a.actor, a.session }
    column :changes, ->(a) {
      ul class: "space-y-2" do
        a.changes.each do |attr, change|
          li do
            h4 class: "font-normal" do
              Member.human_attribute_name(attr)
            end
            div class: "flex items-center" do
              div class: "" do
                display_change_of(attr, change.first, class: "font-extralight")
              end
              div "→", class: "mx-3 font-medium"
              div class: "" do
                display_change_of(attr, change.last, class: "font-extralight")
              end
            end
          end
        end
      end
    }
    column :updated_at, ->(a) { l(a.updated_at, format: :short) }, class: "text-right whitespace-nowrap"
  end

  controller do
    def scoped_collection
      super
        .where(auditable: parent)
        .where(created_at: (parent.created_at + 1.second)..)
    end
  end

  config.sort_order = "updated_at_desc"
  config.per_page = 50
  config.filters = false
end
