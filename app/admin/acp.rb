ActiveAdmin.register ACP do
  menu parent: :other,
    priority: 100,
    label: -> { I18n.t('active_admin.settings') }

  actions :edit, :update
  permit_params \
    :name, :host, :logo_url,
    :url, :email, :phone, :country_code,
    :email_default_host, :email_default_from, :email_footer,
    :trial_basket_count,
    :ccp, :isr_identity, :isr_payment_for, :isr_in_favor_of,
    :qr_iban, :qr_creditor_name,
    :qr_creditor_address, :qr_creditor_city, :qr_creditor_zip,
    :summer_month_range_min, :summer_month_range_max,
    :fiscal_year_start_month, :annual_fee, :share_price,
    :absence_notice_period_in_days,
    :activity_i18n_scope, :activity_participation_deletion_deadline_in_days,
    :activity_availability_limit_in_days, :activity_price, :activity_phone,
    :vat_number, :vat_membership_rate, :absences_billed,
    :delivery_pdf_show_phones,
    :group_buying_email,
    :shop_order_maximum_weight_in_kg, :shop_order_minimal_amount,
    :shop_delivery_open_delay_in_days, :shop_delivery_open_last_day_end_time,
    :recurring_billing_wday, :currency_code,
    :open_renewal_reminder_sent_after_in_days,
    :membership_renewal_depot_update,
    :billing_starts_after_first_delivery,
    :allow_alternative_depots,
    :membership_extra_text_only,
    :basket_price_extras,
    *I18n.available_locales.map { |l| "invoice_info_#{l}" },
    *I18n.available_locales.map { |l| "invoice_footer_#{l}" },
    *I18n.available_locales.map { |l| "email_signature_#{l}" },
    *I18n.available_locales.map { |l| "email_footer_#{l}" },
    *I18n.available_locales.map { |l| "delivery_pdf_footer_#{l}" },
    *I18n.available_locales.map { |l| "terms_of_service_url_#{l}" },
    *I18n.available_locales.map { |l| "statutes_url_#{l}" },
    *I18n.available_locales.map { |l| "membership_extra_text_#{l}" },
    *I18n.available_locales.map { |l| "group_buying_terms_of_service_url_#{l}" },
    *I18n.available_locales.map { |l| "group_buying_invoice_info_#{l}" },
    *I18n.available_locales.map { |l| "shop_invoice_info_#{l}" },
    *I18n.available_locales.map { |l| "open_renewal_text_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_title_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_text_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_label_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_label_detail_#{l}" },
    billing_year_divisions: [],
    languages: [],
    features: []

  form do |f|
    f.inputs t('.details') do
      f.input :name
      f.input :url
      f.input :email, as: :email
      f.input :phone, as: :phone
      f.input :country_code,
        as: :select,
        collection: countries_collection
      f.input :languages,
        as: :check_boxes,
        collection: ACP.languages.map { |l| [t("languages.#{l}"), l] },
        required: true
      f.input :features,
        as: :check_boxes,
        collection: ACP.features.map { |ff| [t("activerecord.models.#{ff}.one"), ff] }
    end
    f.inputs t('.billing') do
      f.input :fiscal_year_start_month,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] },
        prompt: true
      f.input :billing_year_divisions,
        as: :check_boxes,
        collection: ACP.billing_year_divisions.map { |i| [t("billing.year_division.x#{i}"), i] },
        required: true
      f.input :currency_code,
        as: :select,
        collection: ACP::CURRENCIES,
        prompt: true
      f.input :recurring_billing_wday,
        as: :select,
        collection: wdays_collection(t('.recurring_billing_disabled')),
        include_blank: false,
        prompt: false,
        required: false
      f.input :trial_basket_count
      f.input :billing_starts_after_first_delivery, as: :boolean
      if Current.acp.feature?('absence')
        f.input :absences_billed
      end
      f.input :annual_fee, as: :number
      f.input :share_price, as: :number
      f.input :vat_number
      f.input :vat_membership_rate, as: :number, min: 0, max: 100, step: 0.01
      translated_input(f, :invoice_infos)
      translated_input(f, :invoice_footers)
    end
    f.inputs t('.invoice_qr') do
      f.input :qr_iban, required: false, input_html: { maxlength: 21 }, hint: Current.acp.isr_invoice?
      f.input :qr_creditor_name, required: false, input_html: { maxlength: 70 }
      f.input :qr_creditor_address, required: false, input_html: { maxlength: 70 }
      f.input :qr_creditor_city, required: false, input_html: { maxlength: 35 }
      f.input :qr_creditor_zip, required: false, input_html: { maxlength: 16 }
    end
    if Current.acp.isr_invoice?
      f.inputs t('.invoice_isr') do
        f.input :ccp, required: false
        f.input :isr_identity, required: false
        f.input :isr_payment_for, required: false, input_html: { rows: 3 }
        f.input :isr_in_favor_of, required: false, input_html: { rows: 3 }
      end
    end
    f.inputs t('.membership_renewal'), id: 'membership_renewal' do
      para t('.membership_renewal_text_html'), class: 'description'
      translated_input(f, :open_renewal_texts,
        as: :action_text,
        required: false,
        hint: t('formtastic.hints.acp.open_renewal_text'))
      f.input :open_renewal_reminder_sent_after_in_days
      f.input :membership_renewal_depot_update
    end
    f.inputs t('.seasons') do
      para t('.membership_seasons_text'), class: 'description'
      f.input :summer_month_range_min,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] }
      f.input :summer_month_range_max,
        as: :select,
        collection: (1..12).map { |m| [t('date.month_names')[m], m] }
    end
    if Current.acp.feature?('absence')
      f.inputs Absence.model_name.human(count: 2) do
        f.input :absence_notice_period_in_days, min: 1, required: true
      end
    end
    if Current.acp.feature?('activity')
      f.inputs t('.members_participation') do
        f.input :activity_i18n_scope,
          as: :select,
          collection: ACP.activity_i18n_scopes.map { |s| [I18n.t("activities.#{s}", count: 2), s] },
          prompt: true
        f.input :activity_participation_deletion_deadline_in_days
        f.input :activity_availability_limit_in_days, required: true
        f.input :activity_price
        f.input :activity_phone, as: :phone
      end
    end
    if Current.acp.feature?('group_buying')
      f.inputs t('.group_buying') do
        f.input :group_buying_email, as: :email
        translated_input(f, :group_buying_terms_of_service_urls, required: false)
        translated_input(f, :group_buying_invoice_infos,
          hint: t('formtastic.hints.acp.group_buying_invoice_info'),
          required: false)
      end
    end
    if Current.acp.feature_flag?('shop')
      f.inputs t('.shop') do
        f.input :shop_order_maximum_weight_in_kg
        f.input :shop_order_minimal_amount
        f.input :shop_delivery_open_delay_in_days
        f.input :shop_delivery_open_last_day_end_time, as: :time_picker, input_html: {
          step: 900,
          value: resource&.shop_delivery_open_last_day_end_time&.strftime('%H:%M'),
        }
        translated_input(f, :shop_invoice_infos,
          hint: t('formtastic.hints.acp.shop_invoice_info'),
          required: false)
      end
    end
    f.inputs t('.delivery_pdf') do
      translated_input(f, :delivery_pdf_footers, required: false)
      f.input :delivery_pdf_show_phones, as: :boolean
    end
    f.inputs link_to(t('.member_section'), new_members_member_url(subdomain: Current.acp.members_subdomain)) do
      translated_input(f, :terms_of_service_urls, required: false)
      translated_input(f, :statutes_urls, required: false)
      translated_input(f, :membership_extra_texts,
        hint: t('formtastic.hints.acp.membership_extra_text'),
        required: false,
        as: :action_text,
        input_html: { rows: 5 })
      f.input :membership_extra_text_only, as: :boolean
      f.input :allow_alternative_depots, as: :boolean
    end
    if Current.acp.feature_flag?(:basket_price_extra)
      f.inputs ACP.human_attribute_name(:basket_price_extra) do
        translated_input(f, :basket_price_extra_titles, required: false)
        translated_input(f, :basket_price_extra_texts,
          required: false,
          as: :action_text,
          input_html: { rows: 5 })
        f.input :basket_price_extras, as: :string
        translated_input(f, :basket_price_extra_labels,
          as: :text,
          hint: t('formtastic.hints.liquid_extra_html'),
          wrapper_html: { class: 'ace-editor' },
          input_html: { class: 'ace-editor', data: { mode: 'liquid' } })
        translated_input(f, :basket_price_extra_label_details,
          as: :text,
          hint: t('formtastic.hints.liquid_extra_html'),
          wrapper_html: { class: 'ace-editor' },
          input_html: { class: 'ace-editor', data: { mode: 'liquid' } })
      end
    end
    f.inputs t('.mailer'), id: 'mail' do
      para t('.mailer_text_html'), class: 'description'
      f.input :email_default_from, as: :string
      translated_input(f, :email_signatures,
        as: :text,
        required: true,
        input_html: { rows: 2 })
      translated_input(f, :email_footers,
        as: :text,
        required: true,
        input_html: { rows: 2 })
    end

    f.actions do
      f.submit I18n.t('active_admin.edit_model', model: resource.name)
    end
  end

  controller do
    include TranslatedCSVFilename

    defaults singleton: true

    def resource
      @resource ||= Current.acp
    end
  end
end
