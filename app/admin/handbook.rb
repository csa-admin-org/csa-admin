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
      div data: {
        controller: "handbook-search",
        "handbook-search-current-page-value": params[:id],
        action: "keydown.down->handbook-search#navigateDown keydown.up->handbook-search#navigateUp keydown.enter->handbook-search#selectCurrent"
      } do
        # Search form targeting the Turbo Frame below
        form action: handbook_search_path, method: :get,
          data: { "turbo-frame" => "handbook-sidebar-results", "handbook-search-target" => "form" } do |f|
          input type: :hidden, name: :page, value: params[:id]
          div class: "relative mb-3" do
            div class: "pointer-events-none absolute inset-y-0 left-0 flex items-center pl-2.5" do
              icon "magnifying-glass", class: "size-4 text-gray-400 dark:text-gray-500"
            end
            input type: :text, name: :q,
              placeholder: t(".search_placeholder"),
              autocomplete: "off",
              spellcheck: "false",
              data: {
                "handbook-search-target" => "input",
                action: "input->handbook-search#search"
              },
              class: "mt-0 w-full rounded-md border border-gray-300 py-1.5 pl-8 pr-3 text-base sm:text-sm " \
                     "placeholder-gray-400 focus:border-blue-400 focus:ring-1 focus:ring-blue-400 " \
                     "dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder-gray-500 " \
                     "dark:focus:border-blue-500 dark:focus:ring-blue-500"
          end
        end

        # Turbo Frame wrapping the page list — replaced by search results when active
        turbo_frame id: "handbook-sidebar-results", target: "_top",
          data: { "handbook-search-target": "frame", action: "turbo:frame-load->handbook-search#resetSelection" } do
          ul class: "space-y-2 text-base" do
            Handbook.all(binding).each do |handbook|
              next if handbook.restricted? && !current_admin.ultra?

              li do
                if handbook.name == params[:id]
                  div class: "font-bold flex items-center justify-start" do
                    div { icon "chevron-down", class: "size-4 me-1" }
                    span handbook.title
                  end
                  ol class: "mt-2 mb-6 ml-5 list-inside list-none space-y-1" do
                    handbook.subtitles.each do |subtitle, id|
                      li do
                        a href: handbook_page_path(handbook.name, anchor: id) do
                          span subtitle
                        end
                      end
                    end
                  end
                else
                  a href: handbook_page_path(handbook.name) do
                    div class: "flex items-center justify-start" do
                      div { icon "chevron-right", class: "size-4 me-1" }
                      span handbook.title
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
