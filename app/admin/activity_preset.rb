# frozen_string_literal: true

ActiveAdmin.register ActivityPreset do
  menu false
  actions :all, except: [ :show ]

  breadcrumb do
    links = [
      activities_human_name,
      link_to(Activity.model_name.human(count: 2), activities_path)
    ]
    unless params["action"] == "index"
      links << link_to(ActivityPreset.model_name.human(count: 2), activity_presets_path)
      if params["action"].in? %W[edit]
        links << resource.name
      end
    end
    links
  end

  index download_links: false do
    column :title, sortable: true
    column :place, sortable: true
    column :place_url, ->(ap) {
      link_to(truncate(ap.place_url, length: 50), ap.place_url) if ap.place_url?
    }
    actions
  end

  sidebar :info, only: :index do
    side_panel t(".info"), action: handbook_icon_link("activity", anchor: "activities") do
      para t(".activity_preset_info")
    end
  end

  form do |f|
    f.inputs t(".details"), icon: "notebook-text" do
      translated_input(f, :titles,
        placeholder: ->(locale) { I18n.t("formtastic.placeholders.activity_preset.title", locale: locale) })
      translated_input(f, :places,
        placeholder: ->(locale) { I18n.t("formtastic.placeholders.activity_preset.place", locale: locale) })
      translated_input(f, :place_urls,
        hint: t("formtastic.hints.activity_preset.place_url"),
        placeholder: ->(locale) { I18n.t("formtastic.placeholders.activity_preset.place_url", locale: locale) })
    end
    f.actions
  end

  permit_params(
    *I18n.available_locales.map { |l| "place_#{l}" },
    *I18n.available_locales.map { |l| "place_url_#{l}" },
    *I18n.available_locales.map { |l| "title_#{l}" })

  controller do
    include TranslatedCSVFilename
  end

  order_by(:place) do |clause|
    config
      .resource_class
      .order_by_place(clause.order)
      .order_values
      .join(" ")
  end
  order_by(:title) do |clause|
    config
      .resource_class
      .order_by_title(clause.order)
      .order_values
      .join(" ")
  end

  config.filters = false
  config.sort_order = "place_asc"
end
