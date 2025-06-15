# frozen_string_literal: true

ActiveAdmin.before_load do |app|
  module ActiveAdmin
    class DSL
      def sidebar_handbook_link(page, only: :index)
        section = ActiveAdmin::SidebarSection.new(:handbook, only: only) do
          div class: "flex justify-center" do
            a href: "/handbook/#{page}", class: "btn btn-sm btn-light" do
              span do
                icon "book-open", class: "size-5 me-2"
              end
              span do
                t("active_admin.site_footer.handbook")
              end
            end
          end
        end
        config.sidebar_sections << section
      end

      def sidebar_shop_admin_only_warning
        section = ActiveAdmin::SidebarSection.new(
          :shop_admin_only,
          if: -> { Current.org.shop_admin_only },
          only: :index
        ) do
          side_panel nil, class: "warning" do
            para do
              t("active_admin.shared.sidebar_section.shop_admin_only_text_html")
            end
            if authorized?(:read, Current.org)
              div class: "text-center text-sm mt-3" do
                a(href: "/settings#shop") { t("active_admin.shared.sidebar_section.edit_settings") }
              end
            end
          end
        end
        config.sidebar_sections << section
      end
    end
  end
end
