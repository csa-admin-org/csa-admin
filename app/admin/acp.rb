ActiveAdmin.register ACP do
  menu parent: 'Autre', priority: 100, label: 'Paramètres'
  actions :edit, :update
  permit_params :name, :host, features: []

  form do |f|
    f.inputs 'Détails' do
      f.input :name
      f.input :host, hint: '*.host.*'
    end
    f.inputs do
      f.input :features, as: :check_boxes, collection: ACP::FEATURES.map { |f| [t("activerecord.models.#{f}.one"), f] }
    end

    f.actions do
      f.submit t('active_admin.edit_model', model: resource.name)
    end
  end

  controller do
    defaults singleton: true

    def resource
      @resource ||= Current.acp
    end
  end
end
