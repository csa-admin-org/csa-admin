ActiveAdmin.register ACP do
  menu parent: 'Autre', priority: 100, label: 'Paramètres'
  actions :edit, :update
  permit_params :name, :host

  form do |f|
    f.inputs do
      f.input :name
      f.input :host, hint: '*.host.*'
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
