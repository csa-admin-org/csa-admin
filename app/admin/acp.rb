ActiveAdmin.register ACP do
  menu parent: 'Autre', priority: 100, label: 'Paramètres'
  actions :edit, :update
  permit_params \
    :name, :host,
    :email_api_token, :email_default_host, :email_default_from,
    :trial_basket_count,
    :fiscal_year_start_month,
    features: []

  form do |f|
    f.inputs 'Détails' do
      f.input :name
      f.input :host, hint: '*.host.*'
    end
    f.inputs do
      f.input :features,
        as: :check_boxes,
        collection: ACP::FEATURES.map { |f| [t("activerecord.models.#{f}.one"), f] }
    end
    f.inputs 'Mailer (Postmark)' do
      f.input :email_api_token
      f.input :email_default_host
      f.input :email_default_from
    end
    f.inputs 'Abonnement' do
      f.input :trial_basket_count
    end
    f.inputs 'Facturation' do
      f.input :fiscal_year_start_month,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] },
        include_blank: false
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
