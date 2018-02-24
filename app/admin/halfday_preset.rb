ActiveAdmin.register HalfdayPreset do
  menu parent: '½ Journées', priority: 3, label: 'Presets'
  actions :all, except: [:show]

  index do
    column :place
    column :place_url
    column :activity
    actions
  end

  permit_params *%i[place place_url activity]

  config.filters = false
end
