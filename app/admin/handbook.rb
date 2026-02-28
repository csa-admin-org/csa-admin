# frozen_string_literal: true

ActiveAdmin.register_page "Handbook" do
  menu false

  content title: proc { t("active_admin.site_footer.handbook") } do
    handbook = Handbook.new(params[:id], binding)
    feature = params[:id].to_sym
    if Current.org.inactive_feature?(feature)
      info_pane do
          if authorized?(:update, Organization)
            text_node t("active_admin.page.index.handbook_feature_inactive_link_html",
              feature: t("features.#{feature}"),
              url: edit_organization_path(anchor: "organization_features_input"))
          else
            text_node t("active_admin.page.index.handbook_feature_inactive_html",
              feature: t("features.#{feature}"))
          end
      end
    end

    # Mobile floating menu button + modal (visible only below lg breakpoint)
    div class: "mobile-drawer", data: { controller: "mobile-drawer", action: "keydown.esc@window->mobile-drawer#close" } do
      # Floating trigger button
      button \
        class: "mobile-drawer-btn",
        data: { action: "mobile-drawer#open" },
        aria: { label: t("active_admin.shared.sidebar_section.pages") } do
        icon "square-menu", class: "size-6"
      end

      # Modal overlay
      div \
        class: "mobile-drawer-overlay hidden",
        data: {
          "mobile-drawer-target": "overlay",
          action: "click->mobile-drawer#closeOnOutside"
        } do
        div \
          class: "mobile-drawer-panel",
          data: { "mobile-drawer-target": "panel" } do
          # Header with title and close button
          div class: "flex items-center justify-between mb-3" do
            h3 t("active_admin.shared.sidebar_section.pages"), class: "text-xl font-extralight"
            button \
              data: { action: "mobile-drawer#close" },
              class: "p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300",
              aria: { label: "Close" } do
              icon "x-mark", class: "size-5"
            end
          end

          # Menu content
          div class: "text-sm" do
            handbook_menu self,
              current_page: params[:id],
              turbo_frame_id: "handbook-mobile-results",
              link_data: { data: { action: "click->mobile-drawer#navigate" } }
          end
        end
      end
    end

    div \
      class: "markdown md:pr-4 content-page",
      data: {
        turbo: false,
        controller: "handbook-highlight", "handbook-highlight-target": "content"
      } do
      handbook.body
    end
  end

  sidebar :pages, only: :index do
    side_panel t(".pages") do
      handbook_menu self,
        current_page: params[:id],
        turbo_frame_id: "handbook-sidebar-results"
    end
  end

  sidebar :help, if: -> { params[:id] } do
    side_panel t(".help") do
      para t("active_admin.page.index.handbook_questions_html")
    end
  end

  config.breadcrumb = false

  controller do
    before_action do
      redirect_to handbook_page_path(:getting_started) unless params[:id]
    end
  end
end
