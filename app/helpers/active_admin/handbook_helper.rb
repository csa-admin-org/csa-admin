# frozen_string_literal: true

module ActiveAdmin::HandbookHelper
  def handbook_button(arbre, page, **options)
    arbre.para class: "mt-4 flex justify-center" do
      arbre.a href: handbook_page_path(page, **options), class: "btn btn-sm btn-light" do
        arbre.span icon("book-open", class: "size-5 me-1", title: I18n.t("active_admin.site_footer.handbook"))
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
        arbre.div class: "relative mb-3" do
          arbre.div class: "pointer-events-none absolute inset-y-0 left-0 flex items-center pl-2.5" do
            icon "magnifying-glass", class: "size-4 text-gray-400 dark:text-gray-500"
          end
          arbre.input type: :text, name: :q,
            placeholder: I18n.t("active_admin.shared.sidebar_section.search_placeholder"),
            autocomplete: "off",
            spellcheck: "false",
            data: {
              "handbook-search-target" => "input",
              action: "input->handbook-search#search"
            },
            class: "mt-0 w-full rounded-md border border-gray-300 py-1.5 pl-8 pr-3 text-base sm:text-sm " \
                   "placeholder-gray-400 " \
                   "dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder-gray-500"
        end
      end

      arbre.turbo_frame id: turbo_frame_id, target: "_top",
        data: { "handbook-search-target": "frame", action: "turbo:frame-load->handbook-search#resetSelection" } do
        arbre.ul class: "space-y-2 text-base" do
          Handbook.all(binding).each do |handbook|
            next if handbook.restricted? && !current_admin.ultra?

            arbre.li do
              if handbook.name == current_page
                arbre.div class: "font-bold flex items-center justify-start" do
                  arbre.div { icon "chevron-down", class: "size-4 me-1" }
                  arbre.span handbook.title
                end
                arbre.ol class: "mt-2 mb-6 ml-5 list-inside list-none space-y-1" do
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
                  arbre.div class: "flex items-center justify-start" do
                    arbre.div { icon "chevron-right", class: "size-4 me-1" }
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
