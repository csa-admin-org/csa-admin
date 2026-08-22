# frozen_string_literal: true

module ActiveAdmin::AnalyticsHelper
  def analytics_menu(arbre, current_page:, sections: [], link_data: {})
    arbre.ul class: "space-y-2 text-base" do
      Analytics.pages.sort_by { |page| I18n.transliterate(analytics_page_title(page)) }.each do |page|
        arbre.li do
          if page.to_s == current_page.to_s
            arbre.div class: "font-bold flex items-center justify-start" do
              arbre.div { icon "chevron-down", class: "size-4 me-1" }
              arbre.span analytics_page_title(page)
            end
            if sections.any?
              arbre.ol class: "mt-2 mb-6 ml-5 list-inside list-none space-y-1" do
                sections.each do |id, title|
                  arbre.li do
                    arbre.a href: "##{id}", **link_data.deep_merge(data: { turbo: false }) do
                      arbre.span title
                    end
                  end
                end
              end
            end
          else
            arbre.a href: analytics_page_path(page), **link_data do
              arbre.div class: "flex items-center justify-start" do
                arbre.div { icon "chevron-right", class: "size-4 me-1" }
                arbre.span analytics_page_title(page)
              end
            end
          end
        end
      end
    end
  end

  def analytics_page_title(page)
    Analytics::PAGES.fetch(page.to_sym).title
  end

  def analytics_page_icon(page)
    Analytics::PAGES.fetch(page.to_sym).icon
  end

  def analytics_headline_items
    analytics.headlines.map { |item|
      analytics_counter(item.title, item.values, default_index: analytics.default_year_index)
    }
  end

  def analytics_section_links(charts)
    charts.map { |chart| [ chart.id, chart.title ] }
  end

  def analytics_headlines_data
    {
      controller: "analytics--headlines",
      action: "analytics:year->analytics--headlines#update",
      "analytics--headlines-years-value": analytics.year_labels.to_json,
      "analytics--headlines-default-index-value": analytics.default_year_index
    }
  end

  def analytics_year_label
    tag.div analytics.year_labels[analytics.default_year_index],
      class: "analytics-year",
      data: { "analytics--headlines-target": "year" }
  end

  def analytics_counter(title, values, default_index:)
    value = values[default_index]
    content_tag :span, class: "count" do
      concat content_tag(:span, value.nil? ? "–" : value,
        class: "count-value #{"count-zero" if value.nil?}",
        data: { "analytics--headlines-target": "value", values: values.to_json })
      concat content_tag(:span, title, class: "count-title")
    end
  end

  def analytics_chart_html(chart)
    tag.div class: "analytics-chart",
      data: {
        controller: "analytics--chart",
        "analytics--chart-config-value": chart.config
      } do
      tag.canvas
    end
  end
end
