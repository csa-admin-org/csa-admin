ActiveAdmin.register HalfdayPreset do
  menu parent: :halfdays_human_name, priority: 3, label: 'Presets'
  actions :all, except: [:show]

  index download_links: false do
    column :place
    column :place_url, ->(hp) { link_to hp.place_url, hp.place_url }
    column :activity
    actions
  end

  permit_params *%i[place place_url activity]

  config.filters = false
end
