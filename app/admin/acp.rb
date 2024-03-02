ActiveAdmin.register ACP do
  menu priority: 100, label: -> {
    inline_svg_tag("admin/gear.svg", size: "20", title: t("active_admin.settings"))
  }

  actions :edit, :update

  form data: { controller: "code-editor" } do |f|
    div do
      f.object.errors.attribute_names.each do |attr|
        para f.semantic_errors attr
      end
    end

    tabs do
      tab t(".general") do
        f.inputs do
          f.input :name
          f.input :url
          f.input :email, as: :email
          f.input :phone, as: :phone
          f.input :country_code,
            as: :select,
            collection: countries_collection,
            input_html: { disabled: true }
          f.input :languages,
            as: :check_boxes,
            collection: ACP.languages.map { |l| [ t("languages.#{l}"), l ] },
            disabled: ACP.languages
        end
      end
      tab t(".billing"), id: "billing" do
        f.inputs do
          f.input :recurring_billing_wday,
            as: :select,
            collection: wdays_collection(t(".recurring_billing_disabled")),
            include_blank: false,
            prompt: false,
            required: false,
            hint: t("formtastic.hints.acp.recurring_billing_wday_html")
          f.input :billing_year_divisions,
            as: :check_boxes,
            collection: ACP.billing_year_divisions.map { |i| [ t("billing.year_division.x#{i}"), i ] },
            required: true
          f.input :fiscal_year_start_month,
            as: :select,
            collection: (1..12).map { |m| [ t("date.month_names")[m], m ] },
            input_html: { disabled: true }
          f.input :currency_code,
            as: :select,
            collection: ACP::CURRENCIES,
            input_html: { disabled: true }
          f.input :trial_basket_count
          f.input :send_closed_invoice, as: :boolean
          f.input :billing_starts_after_first_delivery, as: :boolean
          f.input :billing_ends_on_last_delivery_fy_month, as: :boolean

          li class: "subtitle" do
            h2 t(".invoice")
          end
          f.input :iban,
            placeholder: Billing.iban_placeholder(f.object.country_code),
            input_html: { value: f.object.iban_formatted }
          if f.object.country_code == "DE"
            f.input :sepa_creditor_identifier, input_html: { maxlength: 35 }
          end
          if f.object.country_code == "CH"
            f.input :bank_reference, input_html: { maxlength: 16 }
          end
          f.input :creditor_name, input_html: { maxlength: 70 }
          f.input :creditor_address, input_html: { maxlength: 70 }
          f.input :creditor_city, input_html: { maxlength: 35 }
          f.input :creditor_zip, input_html: { maxlength: 16 }
          translated_input(f, :invoice_infos,
            hint: t("formtastic.hints.acp.invoice_info"))
          translated_input(f, :invoice_footers,
            hint: t("formtastic.hints.acp.invoice_footer"))

          li class: "subtitle" do
            h2 t(".vat")
            span t(".if_applicable"), class: "optional"
          end
          f.input :vat_number
          f.input :vat_membership_rate, as: :number, min: 0, max: 100, step: 0.01,
            label: t(".vat_rate", type: Membership.model_name.human(count: 2))
          if Current.acp.feature?("activity")
            f.input :vat_activity_rate, as: :number, min: 0, max: 100, step: 0.01,
              label: t(".vat_rate", type: activities_human_name)
          end
          if Current.acp.feature?("shop")
            f.input :vat_shop_rate, as: :number, min: 0, max: 100, step: 0.01,
              label: t(".vat_rate", type: t("shop.title"))
          end

          li class: "subtitle" do
            h2 t(".annual_fee")
            span t(".if_applicable"), class: "optional"
          end
          f.input :annual_fee, as: :number

          li class: "subtitle" do
            h2 t(".shares")
            span t(".if_applicable"), class: "optional"
          end
          f.input :share_price, as: :number, required: false
          f.input :shares_number, as: :number, required: false

          handbook_button(self, "billing")
        end
      end
      tab t(".registration"), id: "registration" do
        f.inputs do
          translated_input(f, :member_form_extra_texts,
            hint: t("formtastic.hints.acp.member_form_extra_text"),
            required: false,
            as: :action_text,
            input_html: { rows: 5 })
          f.input :member_form_extra_text_only, as: :boolean
          translated_input(f, :member_form_complements_texts,
            hint: t("formtastic.hints.acp.member_form_complements_text"),
            required: false,
            as: :action_text,
            input_html: { rows: 5 })
          f.input :basket_sizes_member_order_mode,
            as: :select,
            collection: member_order_modes_collection(BasketSize),
            prompt: true
          f.input :basket_complements_member_order_mode,
            as: :select,
            collection: member_order_modes_collection(BasketComplement),
            prompt: true
          f.input :depots_member_order_mode,
            as: :select,
            collection: member_order_modes_collection(Depot),
            prompt: true
          f.input :delivery_cycles_member_order_mode,
            as: :select,
            collection: member_order_modes_collection(DeliveryCycle),
            prompt: true
          f.input :allow_alternative_depots, as: :boolean
          f.input :member_profession_form_mode,
            label: Member.human_attribute_name(:profession),
            as: :select,
            collection: form_modes_collection,
            include_blank: false,
            required: false
          f.input :member_come_from_form_mode,
            label: Member.human_attribute_name(:come_from),
            as: :select,
            collection: form_modes_collection,
            include_blank: false,
            required: false
          translated_input(f, :charter_urls,
            required: false,
            hint: t("formtastic.hints.acp.registration_url"))
          translated_input(f, :statutes_urls,
            required: false,
            hint: t("formtastic.hints.acp.registration_url"))
          translated_input(f, :terms_of_service_urls,
            required: false,
            hint: t("formtastic.hints.acp.registration_url"))
          translated_input(f, :privacy_policy_urls,
            required: false,
            hint: t("formtastic.hints.acp.registration_url"))

          para class: "actions" do
            a href: new_members_member_url(subdomain: Current.acp.members_subdomain), class: "action" do
              span do
                span inline_svg_tag("admin/external-link.svg", size: "20", title: t("layouts.footer.handbook"))
                span t(".registration_form")
              end
            end.html_safe
          end
        end
      end
      tab t(".member_account"), id: "member_account" do
        f.inputs do
          translated_input(f, :member_information_texts,
            hint: t("formtastic.hints.acp.member_information_text"),
            required: false,
            as: :action_text,
            input_html: { class: "long-text" })
          translated_input(f, :member_information_titles,
            hint: t("formtastic.hints.acp.member_information_title"),
            required: false,
            input_html: { placeholder: t("members.information.default_title") })
        end
      end
      tab Membership.model_name.human, id: "membership" do
        f.inputs do
          para t(".membership_update_text_html"), class: "description"

          f.input :membership_depot_update_allowed
          f.input :membership_complements_update_allowed
          translated_input(f, :membership_update_texts,
            as: :action_text,
            required: false,
            hint: t("formtastic.hints.acp.membership_update_text"))

          f.input :basket_update_limit_in_days, step: 1
        end
      end
      tab t(".membership_renewal"), id: "membership_renewal" do
        f.inputs do
          para t(".membership_renewal_text_html"), class: "description"
          translated_input(f, :open_renewal_texts,
            as: :action_text,
            required: false,
            hint: t("formtastic.hints.acp.open_renewal_text"))
          f.input :open_renewal_reminder_sent_after_in_days
          f.input :membership_renewed_attributes, as: :check_boxes,
            collection: membership_renewed_attributes_collection
          f.input :membership_renewal_depot_update

          handbook_button(self, "membership_renewal")
        end
      end
      tab Delivery.human_attribute_name(:sheets) do
        f.inputs do
          para t(".delivery_sheets_text_html"), class: "description"
          translated_input(f, :delivery_pdf_footers, required: false)
          f.input :delivery_pdf_show_phones, as: :boolean
        end
      end
      tab t(".mailer"), id: "mail"  do
        f.inputs do
          para t(".mailer_text_html"), class: "description"
          f.input :email_default_from, as: :string
          translated_input(f, :email_signatures,
            as: :text,
            required: true,
            input_html: { rows: 3 })
          translated_input(f, :email_footers,
            as: :text,
            required: true,
            input_html: { rows: 3 })
        end
      end
    end

    f.input :features,
      as: :check_boxes,
      wrapper_html: { class: "no-check-boxes-toggle-all detailed-option" },
      collection: ACP.features.map { |ff|
        [
          content_tag(:span) {
            content_tag(:span, t("features.#{ff}")) +
            content_tag(:span, t("features.#{ff}_hint").html_safe, class: "hint")
          },
          ff
        ]
      }

    if Current.acp.features.any?
      tabs do
        if Current.acp.feature?("absence")
          tab Absence.model_name.human, id: "absence" do
            f.inputs do
              translated_input(f, :absence_extra_texts,
                hint: t("formtastic.hints.acp.absence_extra_text"),
                required: false,
                as: :action_text,
                input_html: { rows: 5 })
              f.input :absence_extra_text_only, as: :boolean

              f.input :absences_billed
              f.input :absence_notice_period_in_days, min: 1, required: true

              handbook_button(self, "absences")
            end
          end
        end
        if Current.acp.feature?("activity")
          tab t(".members_participation"), id: "activity" do
            f.inputs do
              f.input :activity_i18n_scope,
                as: :select,
                collection: ACP.activity_i18n_scopes.map { |s| [ t("activities.#{s}", count: 2), s ] },
                prompt: true
              f.input :activity_price
              f.input :activity_participations_form_min
              f.input :activity_participations_form_max
              translated_input(f, :activity_participations_form_details,
                hint: t("formtastic.hints.acp.activity_participations_demanded_annually_form_detail"),
                required: false,
                placeholder: ->(locale) {
                  I18n.with_locale(locale) {
                    activity_participations_form_detail(force_default: true)
                  }
                })
              f.input :activity_participations_demanded_logic,
                as: :text,
                hint: t("formtastic.hints.acp.activity_participations_demanded_logic_html"),
                wrapper_html: { class: "ace-editor" },
                input_html: {
                  class: "ace-editor",
                  data: { mode: "liquid", code_editor_target: "editor" }
                }

              f.input :activity_availability_limit_in_days, required: true
              f.input :activity_participation_deletion_deadline_in_days
              f.input :activity_phone, as: :phone

              handbook_button(self, "activity")
            end
          end
        end
        if Current.acp.feature?("shop")
          tab t(".shop"), id: "shop" do
            f.inputs do
              f.input :shop_admin_only
              translated_input(f, :shop_texts,
                as: :action_text,
                required: false,
                hint: t("formtastic.hints.acp.shop_text"))
              translated_input(f, :shop_terms_of_sale_urls,
                required: false,
                hint: t("formtastic.hints.acp.shop_terms_of_sale_url"))
              f.input :shop_order_maximum_weight_in_kg
              f.input :shop_order_minimal_amount
              f.input :shop_member_percentages,
                as: :string,
                input_html: { value: f.object.shop_member_percentages }
              f.input :shop_delivery_open_delay_in_days
              f.input :shop_delivery_open_last_day_end_time, as: :time_picker, input_html: {
                value: f.object.shop_delivery_open_last_day_end_time&.strftime("%H:%M")
              }
              f.input :shop_order_automatic_invoicing_delay_in_days
              translated_input(f, :shop_invoice_infos,
                hint: t("formtastic.hints.acp.shop_invoice_info"),
                required: false)
              translated_input(f, :shop_delivery_pdf_footers, required: false)

              handbook_button(self, "shop")
            end
          end
        end
        if Current.acp.feature?("new_member_fee")
          tab t("features.new_member_fee"), id: "new_member_fee" do
            f.inputs do
              translated_input(f, :new_member_fee_descriptions,
                required: true,
                label: ->(_) { InvoiceItem.human_attribute_name(:description) },
                hint: t("formtastic.hints.acp.new_member_fee_description"))
              f.input :new_member_fee,
                required: true,
                min: 0,
                step: 0.05,
                label: InvoiceItem.human_attribute_name(:amount)

              handbook_button(self, "new_member_fee")
            end
          end
        end
        if Current.acp.feature?("basket_price_extra")
          tab ACP.human_attribute_name(:basket_price_extra), id: "basket_price_extra" do
            f.inputs do
              translated_input(f, :basket_price_extra_titles, required: false)
              translated_input(f, :basket_price_extra_public_titles,
                hint: t("formtastic.hints.acp.basket_price_extra_public_title"),
                required: false)
              translated_input(f, :basket_price_extra_texts,
                hint: t("formtastic.hints.acp.basket_price_extra_text"),
                required: false,
                as: :action_text,
                input_html: { rows: 5 })
              f.input :basket_price_extras,
                as: :string,
                input_html: { value: f.object.basket_price_extras }
              translated_input(f, :basket_price_extra_labels,
                as: :text,
                hint: t("formtastic.hints.acp.basket_price_extra_labels_html"),
                wrapper_html: { class: "ace-editor" },
                input_html: {
                  class: "ace-editor",
                  data: { mode: "liquid", code_editor_target: "editor" }
                })
              translated_input(f, :basket_price_extra_label_details,
                as: :text,
                placeholder: Current.acp.basket_price_extra_label_detail_default,
                hint: t("formtastic.hints.acp.basket_price_extra_label_details_html"),
                wrapper_html: { class: "ace-editor" },
                input_html: {
                  class: "ace-editor",
                  data: { mode: "liquid", code_editor_target: "editor" }
                })

              f.input :basket_price_extra_dynamic_pricing,
                as: :text,
                hint: t("formtastic.hints.acp.basket_price_extra_dynamic_pricing_html"),
                wrapper_html: { class: "ace-editor" },
                input_html: {
                  class: "ace-editor",
                  data: { mode: "liquid", code_editor_target: "editor" }
                }

              handbook_button(self, "basket_price_extra")
            end
          end
        end
      end
    end

    f.actions do
      f.submit t("active_admin.resources.acp.submit")
    end
  end

  permit_params \
    :name, :host,
    :url, :email, :phone,
    :email_default_host, :email_default_from, :email_footer,
    :trial_basket_count,
    :iban, :sepa_creditor_identifier, :bank_reference, :creditor_name,
    :creditor_address, :creditor_city, :creditor_zip,
    :annual_fee, :share_price, :shares_number,
    :absence_notice_period_in_days,
    :activity_i18n_scope, :activity_participation_deletion_deadline_in_days,
    :activity_availability_limit_in_days, :activity_price, :activity_phone,
    :activity_participations_form_min, :activity_participations_form_max,
    :activity_participations_demanded_logic,
    :vat_number, :vat_membership_rate, :vat_activity_rate, :vat_shop_rate,
    :absences_billed,
    :delivery_pdf_show_phones,
    :shop_admin_only,
    :shop_order_maximum_weight_in_kg, :shop_order_minimal_amount,
    :shop_member_percentages,
    :shop_delivery_open_delay_in_days, :shop_delivery_open_last_day_end_time,
    :shop_order_automatic_invoicing_delay_in_days,
    :recurring_billing_wday,
    :send_closed_invoice,
    :open_renewal_reminder_sent_after_in_days,
    :membership_renewal_depot_update,
    :billing_starts_after_first_delivery, :billing_ends_on_last_delivery_fy_month,
    :allow_alternative_depots,
    :member_form_extra_text_only,
    :basket_sizes_member_order_mode, :basket_complements_member_order_mode,
    :depots_member_order_mode, :delivery_cycles_member_order_mode,
    :basket_price_extras,
    :absence_extra_text_only,
    :member_profession_form_mode, :member_come_from_form_mode,
    :membership_depot_update_allowed, :membership_complements_update_allowed,
    :basket_update_limit_in_days,
    :basket_price_extra_dynamic_pricing,
    :new_member_fee,
    *I18n.available_locales.map { |l| "invoice_info_#{l}" },
    *I18n.available_locales.map { |l| "invoice_footer_#{l}" },
    *I18n.available_locales.map { |l| "email_signature_#{l}" },
    *I18n.available_locales.map { |l| "email_footer_#{l}" },
    *I18n.available_locales.map { |l| "delivery_pdf_footer_#{l}" },
    *I18n.available_locales.map { |l| "charter_url_#{l}" },
    *I18n.available_locales.map { |l| "statutes_url_#{l}" },
    *I18n.available_locales.map { |l| "terms_of_service_url_#{l}" },
    *I18n.available_locales.map { |l| "privacy_policy_url_#{l}" },
    *I18n.available_locales.map { |l| "member_form_extra_text_#{l}" },
    *I18n.available_locales.map { |l| "member_form_complements_text_#{l}" },
    *I18n.available_locales.map { |l| "shop_invoice_info_#{l}" },
    *I18n.available_locales.map { |l| "shop_delivery_pdf_footer_#{l}" },
    *I18n.available_locales.map { |l| "shop_terms_of_sale_url_#{l}" },
    *I18n.available_locales.map { |l| "shop_text_#{l}" },
    *I18n.available_locales.map { |l| "open_renewal_text_#{l}" },
    *I18n.available_locales.map { |l| "absence_extra_text_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_title_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_public_title_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_text_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_label_#{l}" },
    *I18n.available_locales.map { |l| "basket_price_extra_label_detail_#{l}" },
    *I18n.available_locales.map { |l| "membership_update_text_#{l}" },
    *I18n.available_locales.map { |l| "member_information_title_#{l}" },
    *I18n.available_locales.map { |l| "member_information_text_#{l}" },
    *I18n.available_locales.map { |l| "new_member_fee_description_#{l}" },
    *I18n.available_locales.map { |l| "activity_participations_form_detail_#{l}" },
    billing_year_divisions: [],
    features: [],
    membership_renewed_attributes: []

  controller do
    include TranslatedCSVFilename
    include FormsHelper

    defaults singleton: true

    def update
      update! do |success, failure|
        success.html do
          if resource.features_previously_changed? && (resource.features.map(&:to_s) - resource.features_previously_was).any?
            new_feature = (resource.features.map(&:to_s) - resource.features_previously_was).first
            redirect_to "/settings##{new_feature}"
          else
            redirect_to "/"
          end
        end
      end
    end

    def resource
      @resource ||= Current.acp
    end
  end
end
