ActiveAdmin.register ACP do
  menu parent: :other, priority: 100, label: 'Paramètres'
  actions :edit, :update
  permit_params \
    :name, :host, :logo,
    :email_default_host, :email_default_from,
    :trial_basket_count,
    :ccp, :isr_identity, :isr_payment_for, :isr_in_favor_of,
    :summer_month_range_min, :summer_month_range_max,
    :fiscal_year_start_month, :annual_fee, :share_price,
    :halfday_i18n_scope, :halfday_participation_deletion_deadline_in_days,
    :url, :email, :phone,
    :vat_number, :vat_membership_rate,
    billing_year_divisions: [],
    languages: [],
    features: [],
    invoice_infos: I18n.available_locales,
    invoice_footers: I18n.available_locales,
    delivery_pdf_footers: I18n.available_locales,
    terms_of_service_urls: I18n.available_locales,
    statutes_urls: I18n.available_locales

  form do |f|
    f.inputs 'Détails' do
      f.input :name
      f.input :host, hint: '*.host.*'
      f.input :logo, as: :file
      f.input :languages,
        as: :check_boxes,
        collection: ACP.languages.map { |l| [t("languages.#{l}"), l] }
    end
    f.inputs do
      f.input :features,
        as: :check_boxes,
        collection: ACP.features.map { |ff| [t("activerecord.models.#{ff}.one"), ff] }
    end
    f.inputs 'Mailer (Postmark)' do
      f.input :email_default_host, as: :string
      f.input :email_default_from, as: :string
    end
    f.inputs 'Abonnement' do
      f.input :trial_basket_count
    end
    f.inputs 'Saisons (été/hiver)' do
      f.input :summer_month_range_min,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] }
      f.input :summer_month_range_max,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] }
    end
    f.inputs 'Facturation' do
      f.input :fiscal_year_start_month,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] },
        prompt: true
      f.input :billing_year_divisions,
        as: :check_boxes,
        collection: ACP.billing_year_divisions.map { |i| [t("billing.year_division.x#{i}"), i] }
      f.input :annual_fee, as: :number
      f.input :share_price, as: :number
      f.input :vat_number
      f.input :vat_membership_rate, as: :number, min: 0, max: 100, step: 0.01
    end
    f.inputs 'Facture (BVR)' do
      f.input :ccp
      f.input :isr_identity
      f.input :isr_payment_for
      f.input :isr_in_favor_of
      translated_input(f, :invoice_infos)
      translated_input(f, :invoice_footers)
    end
    f.inputs 'Participation des membres' do
      f.input :halfday_i18n_scope,
        label: 'Appellation',
        as: :select,
        collection: ACP.halfday_i18n_scopes.map { |s| [t("halfdays.#{s}", count: 2), s] },
        prompt: true
      f.input :halfday_participation_deletion_deadline_in_days
    end
    f.inputs 'Fiches signature livraison (PDF)' do
      translated_input(f, :delivery_pdf_footers, required: false)
    end
    f.inputs 'Page de membre' do
      f.input :url
      f.input :email
      f.input :phone
      translated_input(f, :terms_of_service_urls, required: false)
      translated_input(f, :statutes_urls, required: false)
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
