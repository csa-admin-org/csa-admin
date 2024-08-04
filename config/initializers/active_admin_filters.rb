# Add filters stimulus controller for live fitlering
ActiveAdmin.before_load do |app|
  module ActiveAdmin
    module Filters
      module ResourceExtension
        def filters_sidebar_section
          name = :filters
          ActiveAdmin::SidebarSection.new name, only: :index, if: -> { active_admin_config.filters.any? } do
            h3 I18n.t("active_admin.sidebars.#{name}", default: name.to_s.titlecase), class: "filters-form-title"
            active_admin_filters_form_for assigns[:search], active_admin_config.filters,
              data: {
                controller: "filters",
                action: "change->filters#submit"
              }
          end
        end
      end
    end
  end
end
