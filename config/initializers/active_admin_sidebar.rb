ActiveAdmin.before_load do |app|
  module ActiveAdmin
    class DSL
      def sidebar_handbook_link(page, only: :index)
        section = ActiveAdmin::SidebarSection.new(:handbook, only: only) do
          div class: "flex justify-center" do
            a href: "/handbook/#{page}", class: "action-item-button small light" do
              span do
                icon "book-open", class: "w-5 h-5 me-2"
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
          if: -> { Current.acp.shop_admin_only },
          only: :index
        ) do
          para class: "p-2 rounded text-sm text-red-800 dark:text-red-100 bg-red-100 dark:bg-red-800" do
            t("active_admin.shared.sidebar_section.shop_admin_only_text_html")
          end
          if authorized?(:read, Current.acp)
            div class: "text-center text-sm mt-3" do
              a(href: "/settings#shop") { t("active_admin.shared.sidebar_section.edit_settings") }
            end
          end
        end
        config.sidebar_sections << section
      end
    end
  end
end
