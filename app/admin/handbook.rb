# frozen_string_literal: true

ActiveAdmin.register_page "Handbook" do
  menu false

  breadcrumb do
    [ t("active_admin.site_header.handbook") ]
  end

  content title: proc {
    if params[:id].present?
      Handbook.new(params[:id], binding).title
    else
      t("active_admin.site_header.handbook")
    end
  } do
    handbook = Handbook.new(params[:id], binding)
    feature = params[:id].to_sym
    if Current.org.inactive_feature?(feature)
      info_pane do
        if authorized?(:update, Organization)
          text_node t("active_admin.page.index.handbook_feature_inactive_link_html",
            feature: t("features.#{feature}"),
            url: edit_organization_path(feature, activate: true))
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
        icon "square-menu", class: "mobile-drawer-btn-icon"
      end

      # Modal overlay
      div \
        class: "mobile-drawer-overlay is-hidden",
        data: {
          "mobile-drawer-target": "overlay",
          action: "click->mobile-drawer#closeOnOutside"
        } do
        div \
          class: "mobile-drawer-panel",
          data: { "mobile-drawer-target": "panel" } do
          div class: "admin-drawer-header" do
            h3 t("active_admin.shared.sidebar_section.pages"), class: "admin-drawer-title"
            button \
              data: { action: "mobile-drawer#close" },
              class: "admin-drawer-close",
              aria: { label: t("accessibility.active_admin.close") } do
              icon "x", class: "admin-drawer-close-icon"
            end
          end

          div class: "admin-drawer-menu" do
            handbook_menu self,
              current_page: params[:id],
              turbo_frame_id: "handbook-mobile-results",
              link_data: { data: { action: "click->mobile-drawer#navigate" } }
          end
        end
      end
    end

    div \
      class: "markdown content-page",
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

  controller do
    before_action do
      default_page = Tenant.demo? ? :setup : :getting_started
      redirect_to handbook_page_path(default_page) unless params[:id]
    end
  end
end
