# frozen_string_literal: true

module ActiveAdmin::HandbookHelper
  def handbook_button(arbre, page, **options)
    arbre.para class: "handbook-button" do
      arbre.a href: handbook_page_path(page, **options), class: "btn btn-sm btn-light" do
        arbre.span icon("book-open", class: "icon-4", title: I18n.t("active_admin.site_footer.handbook"))
        arbre.span t(".check_handbook")
      end.html_safe
    end
  end

  def handbook_menu(arbre, current_page:, turbo_frame_id:, link_data: {})
    arbre.div data: {
      controller: "handbook-search",
      "handbook-search-current-page-value": current_page,
      action: "keydown.down->handbook-search#navigateDown keydown.up->handbook-search#navigateUp keydown.enter->handbook-search#selectCurrent"
    } do
      arbre.form action: handbook_search_path, method: :get,
        data: { "turbo-frame" => turbo_frame_id, "handbook-search-target" => "form" } do
        arbre.input type: :hidden, name: :page, value: current_page
        arbre.div class: "handbook-search" do
          arbre.div class: "handbook-search-icon" do
            icon "search", class: "icon-4 is-faint"
          end
          arbre.input type: :text, name: :q,
            placeholder: I18n.t("active_admin.shared.sidebar_section.search_placeholder"),
            autocomplete: "off",
            spellcheck: "false",
            data: {
              "handbook-search-target" => "input",
              action: "input->handbook-search#search"
            },
            class: "handbook-search-input"
        end
      end

      arbre.turbo_frame id: turbo_frame_id, target: "_top",
        data: { "handbook-search-target": "frame", action: "turbo:frame-load->handbook-search#resetSelection" } do
        arbre.ul class: "admin-page-menu" do
          Handbook.all(binding).each do |handbook|
            next if handbook.restricted? && !current_admin.ultra?
            next if handbook.demo_only? && !Tenant.demo?
            next if Current.org.inactive_feature?(handbook.name) && !authorized?(:update, Organization)

            li_opts = {}
            li_opts[:class] = "admin-page-menu-pinned" if handbook.name == "getting_started"
            arbre.li(**li_opts) do
              if handbook.name == current_page
                arbre.div class: "admin-page-menu-current" do
                  arbre.div { icon "chevron-down", class: "icon-4" }
                  arbre.span handbook.title
                end
                arbre.ol class: "admin-page-menu-subs" do
                  handbook.subtitles.each do |subtitle, id|
                    arbre.li do
                      arbre.a href: handbook_page_path(handbook.name, anchor: id), **link_data do
                        arbre.span subtitle
                      end
                    end
                  end
                end
              else
                arbre.a href: handbook_page_path(handbook.name), **link_data do
                  arbre.div class: "admin-page-menu-link" do
                    arbre.div { icon "chevron-right", class: "icon-4" }
                    arbre.span handbook.title
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
