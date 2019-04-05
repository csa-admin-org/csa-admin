ActiveAdmin.register ACP do
  menu parent: :other,
    priority: 100,
    label: -> { I18n.t('active_admin.settings') }

  actions :edit, :update
  permit_params \
    :name, :host, :logo_url,
    :url, :email, :phone,
    :email_default_host, :email_default_from, :email_footer,
    :trial_basket_count,
    :ccp, :isr_identity, :isr_payment_for, :isr_in_favor_of,
    :summer_month_range_min, :summer_month_range_max,
    :fiscal_year_start_month, :annual_fee, :share_price,
    :activity_i18n_scope, :activity_participation_deletion_deadline_in_days,
    :activity_availability_limit_in_days, :activity_price, :activity_phone,
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
    f.inputs t('.details') do
      f.input :name
      f.input :url
      f.input :logo_url, hint: '300x300px (CDN 🙏)'
      f.input :email, as: :email
      f.input :phone, as: :phone
    end
    f.inputs do
      f.input :languages,
        as: :check_boxes,
        collection: ACP.languages.map { |l| [t("languages.#{l}"), l] }
      f.input :features,
        as: :check_boxes,
        collection: ACP.features.map { |ff| [t("activerecord.models.#{ff}.one"), ff] }
    end
    f.inputs Membership.model_name.human(count: 2) do
      f.input :trial_basket_count
    end
    f.inputs t('.seasons') do
      f.input :summer_month_range_min,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] }
      f.input :summer_month_range_max,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] }
    end
    f.inputs t('.billing') do
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
    f.inputs t('.invoice_isr') do
      f.input :ccp
      f.input :isr_identity
      f.input :isr_payment_for
      f.input :isr_in_favor_of
      translated_input(f, :invoice_infos)
      translated_input(f, :invoice_footers)
    end
    if Current.acp.feature?('activity')
      f.inputs t('.members_participation') do
        f.input :activity_i18n_scope,
          as: :select,
          collection: ACP.activity_i18n_scopes.map { |s| [t("activities.#{s}", count: 2), s] },
          prompt: true
        f.input :activity_participation_deletion_deadline_in_days
        f.input :activity_availability_limit_in_days
        f.input :activity_price
        f.input :activity_phone, as: :phone
      end
    end
    f.inputs t('.delivery_pdf') do
      translated_input(f, :delivery_pdf_footers, required: false)
    end
    f.inputs t('.member_section') do
      translated_input(f, :terms_of_service_urls, required: false)
      translated_input(f, :statutes_urls, required: false)
    end
    f.inputs t('.mailer') do
      f.input :email_default_host, as: :string
      f.input :email_default_from, as: :string
      f.input :email_footer, as: :string
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
