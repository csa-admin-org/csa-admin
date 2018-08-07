ActiveAdmin.register HalfdayPreset do
  menu parent: :halfdays_human_name,
    priority: 3,
    label: -> { Halfday.human_attribute_name(:presets) }

  actions :all, except: [:show]

  index download_links: false do
    column :place
    column :place_url, ->(hp) { link_to truncate(hp.place_url, length: 50), hp.place_url }
    column :activity
    actions
  end

  form do |f|
    f.inputs do
      translated_input(f, :places)
      translated_input(f, :place_urls)
      translated_input(f, :activities)
      f.actions
    end
  end

  permit_params(
    places: I18n.available_locales,
    place_urls: I18n.available_locales,
    activities: I18n.available_locales)

  config.filters = false
  config.per_page = 50
  config.sort_order = -> { "places->>'#{I18n.locale}'" }
end
