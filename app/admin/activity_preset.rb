ActiveAdmin.register ActivityPreset do
  menu parent: :activities_human_name, priority: 3
  actions :all, except: [:show]

  breadcrumb do
    links = [activities_human_name]
    unless params['action'] == 'index'
      links << link_to(ActivityPreset.model_name.human(count: 2), activity_presets_path)
      if params['action'].in? %W[edit]
        links << activity_preset.name
      end
    end
    links
  end

  index download_links: false do
    column :place
    column :place_url, ->(ap) { link_to truncate(ap.place_url, length: 50), ap.place_url }
    column :title
    actions
  end

  form do |f|
    f.inputs do
      translated_input(f, :places)
      translated_input(f, :place_urls)
      translated_input(f, :titles)
    end
    f.actions
  end

  permit_params(
    places: I18n.available_locales,
    place_urls: I18n.available_locales,
    titles: I18n.available_locales)

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.per_page = 50
  config.sort_order = -> { "places->>'#{I18n.locale}'" }
end
