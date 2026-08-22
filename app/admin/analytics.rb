# frozen_string_literal: true

ActiveAdmin.register_page "Analytics" do
  menu false

  breadcrumb do
    [ t("active_admin.site_header.analytics") ]
  end

  content title: proc {
    page = params[:id]
    if page.present? && Analytics.pages.map(&:to_s).include?(page)
      Analytics::PAGES.fetch(page.to_sym).title
    else
      t("active_admin.site_header.analytics")
    end
  } do
    page = controller.analytics_page
    charts = controller.analytics_charts
    sections = controller.analytics_sections

    div class: "mobile-drawer", data: { controller: "mobile-drawer", action: "keydown.esc@window->mobile-drawer#close" } do
      button \
        class: "mobile-drawer-btn",
        data: { action: "mobile-drawer#open" },
        aria: { label: t("active_admin.shared.sidebar_section.pages") } do
        icon "square-menu", class: "size-6"
      end

      div \
        class: "mobile-drawer-overlay hidden",
        data: {
          "mobile-drawer-target": "overlay",
          action: "click->mobile-drawer#closeOnOutside"
        } do
        div class: "mobile-drawer-panel", data: { "mobile-drawer-target": "panel" } do
          div class: "flex items-center justify-between mb-3" do
            h3 t("active_admin.shared.sidebar_section.pages"), class: "text-xl font-extralight"
            button \
              data: { action: "mobile-drawer#close" },
              class: "p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300",
              aria: { label: t("accessibility.active_admin.close") } do
              icon "x", class: "size-5"
            end
          end

          div class: "text-sm" do
            analytics_menu self,
              current_page: page,
              sections: sections,
              link_data: { data: { action: "click->mobile-drawer#navigate" } }
          end
        end
      end
    end

    analytics = controller.analytics
    if analytics.empty?
      panel analytics_page_title(page), icon: analytics_page_icon(page) do
        div class: "missing-data" do
          text_node t("analytics.empty.#{page}")
        end
      end
    else
      div data: analytics_headlines_data do
        div class: "panel analytics-headlines-panel" do
          div class: "panel-body" do
            text_node analytics_year_label
            ul class: "counts analytics-counts" do
              analytics_headline_items.each do |item|
                li { text_node item }
              end
            end
          end
        end

        div class: "mt-8 space-y-8 analytics-charts" do
          charts.each do |chart|
            panel chart.title, id: chart.id, class: "scroll-mt-24", icon: chart.icon do
              text_node analytics_chart_html(chart)
            end
          end
        end
      end
    end
  end

  sidebar :pages, only: :index do
    side_panel t(".pages") do
      analytics_menu self,
        current_page: controller.analytics_page,
        sections: controller.analytics_sections
    end
  end

  controller do
    helper_method :analytics_page, :analytics, :analytics_charts, :analytics_sections

    before_action do
      pages = Analytics.pages
      page = params[:id].presence
      next if page && pages.map(&:to_s).include?(page)

      redirect_to analytics_page_path(pages.first)
    end

    def analytics_page
      params[:id].to_sym
    end

    def analytics
      @analytics ||= Analytics.for(analytics_page)
    end

    def analytics_charts
      return [] unless analytics
      return [] if analytics.empty?

      @analytics_charts ||= analytics.charts
    end

    def analytics_sections
      helpers.analytics_section_links(analytics_charts)
    end
  end
end
