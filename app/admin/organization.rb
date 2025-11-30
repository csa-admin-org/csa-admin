# frozen_string_literal: true

ActiveAdmin.register Organization do
  menu false

  actions :edit, :update

  form data: { controller: "code-editor" } do |f|
    if f.object.errors.any?
      div class: "mb-6" do
        f.object.errors.attribute_names.each do |attr|
          para f.semantic_errors attr
        end
      end
    end

    f.inputs do
      tabs do
        tab t(".general"), id: "general" do
          f.input :name
          f.input :url, input_html: { disabled: true }
          f.input :email, as: :email
          f.input :phone, as: :phone
          f.input :social_network_urls, as: :string
          f.input :country_code,
            as: :select,
            collection: countries_collection,
            input_html: { disabled: true }
          f.input :languages,
            as: :check_boxes,
            wrapper_html: { class: "single-column" },
            toggle_all: false,
            collection: org_languages_collection,
            disabled: Organization.languages
          if current_admin.ultra?
            f.input :logo, as: :file
            if resource.logo.attached?
              div class: "mt-2" do
                image_tag resource.logo, class: "h-16"
              end
            end
          end
        end
        tab t(".billing"), id: "billing" do
          f.input :recurring_billing_wday,
            as: :select,
            collection: wdays_collection(t(".recurring_billing_disabled")),
            include_blank: false,
            prompt: false,
            required: false,
            hint: t("formtastic.hints.organization.recurring_billing_wday_html")
          f.input :billing_year_divisions,
            as: :check_boxes,
            wrapper_html: { class: "single-column" },
            toggle_all: false,
            collection: billing_year_divisions_collection,
            required: true
          f.input :fiscal_year_start_month,
            as: :select,
            collection: (1..12).map { |m| [ t("date.month_names")[m], m ] },
            input_html: { disabled: true }
          f.input :currency_code,
            as: :select,
            collection: Organization.currency_codes,
            input_html: { disabled: true }
          f.input :trial_baskets_count
          f.input :send_closed_invoice, as: :boolean
          f.input :billing_starts_after_first_delivery, as: :boolean
          f.input :billing_ends_on_last_delivery_fy_month, as: :boolean

          li class: "subtitle" do
            h2 t(".invoice")
          end
          f.input :iban,
            label: f.object.swiss_qr? ? "QR-IBAN" : "IBAN",
            placeholder: Billing.iban_placeholder(f.object.country_code),
            input_html: { value: f.object.iban_formatted }
          if f.object.sepa?
            f.input :sepa_creditor_identifier, input_html: { maxlength: 35, placeholder: sepa_creditor_identifier_placeholder }
          end
          if f.object.swiss_qr?
            f.input :bank_reference, input_html: { maxlength: 16 }
          end
          f.input :creditor_name, input_html: { maxlength: 70 }
          f.input :creditor_street, input_html: { maxlength: 70 }
          div class: "single-line" do
            f.input :creditor_zip, input_html: { maxlength: 16 }, wrapper_html: { class: "md:w-50" }
            f.input :creditor_city, input_html: { maxlength: 35 }, wrapper_html: { class: "w-full" }
          end
          if f.object.sepa?
            translated_input(f, :invoice_document_names,
              hint: t("formtastic.hints.organization.invoice_document_name_html"),
              input_html: { placeholder: Invoice.model_name.human })
          end
          translated_input(f, :invoice_infos,
            hint: t("formtastic.hints.organization.invoice_info"))
          if f.object.sepa?
            translated_input(f, :invoice_sepa_infos,
              hint: t("formtastic.hints.organization.invoice_sepa_info"))
          end
          f.input :invoice_logos, as: :file, input_html: { accept: "image/jpeg, image/png", multiple: true, class: "mt-1.5" }
          ul class: "flex flex-nowrap flex-row gap-x-8"  do
            resource.invoice_logos.select(&:persisted?).each do |invoice_logo|
              li class: "relative" do
                span class: "absolute -top-3 -right-3 text-gray-500 z-50 cursor-pointer", onclick: "this.parentNode.remove()" do
                  icon("x-circle", class: "size-6")
                end
                f.hidden_field :invoice_logos, multiple: true, value: invoice_logo.signed_id
                 span do
                   image_tag invoice_logo.variant(resize_to_limit: [ 256, 256 ]), class: "h-16"
                 end
              end
            end
          end
          translated_input(f, :invoice_footers,
            hint: t("formtastic.hints.organization.invoice_footer"),
            as: :text, input_html: { rows: 2 })

          li class: "subtitle" do
            h2 t(".vat")
            span t(".if_applicable"), class: "optional"
          end
          f.input :vat_number, input_html: {
            placeholder: Current.org.swiss_qr? ? "CHE-123.456.789" : nil
          }
          f.input :vat_membership_rate, as: :number, min: 0, max: 100, step: 0.01,
            label: t(".vat_rate", type: Membership.model_name.human(count: 2))
          if feature?("activity")
            f.input :vat_activity_rate, as: :number, min: 0, max: 100, step: 0.01,
              label: t(".vat_rate", type: activities_human_name)
          end
          if feature?("shop")
            f.input :vat_shop_rate, as: :number, min: 0, max: 100, step: 0.01,
              label: t(".vat_rate", type: t("shop.title"))
          end

          li class: "subtitle" do
            h2 t(".annual_fee")
            span t(".if_applicable"), class: "optional"
            para t(".annual_fee_hint"), class: "pt-2"
          end
          f.input :annual_fee, as: :number
          f.input :annual_fee_support_member_only, as: :boolean
          f.input :annual_fee_member_form, as: :boolean

          li class: "subtitle" do
            h2 t(".shares")
            span t(".if_applicable"), class: "optional"
          end
          f.input :share_price, as: :number, required: false
          f.input :shares_number, as: :number, required: false

          handbook_button(self, "billing")
        end
        tab t(".registration"), id: "registration" do
          translated_input(f, :member_form_subtitles,
            hint: t("formtastic.hints.organization.member_form_subtitle"),
            placeholder: ->(locale) {
              I18n.with_locale(locale) {
                I18n.t("members.members.new.subtitle")
              }
            },
            required: false,
            as: :action_text,
            input_html: { rows: 1 })


          li class: "subtitle" do
            h2 t("members.members.form_modes.membership.title")
          end
          translated_input(f, :member_form_extra_texts,
            hint: t("formtastic.hints.organization.member_form_extra_text"),
            required: false,
            as: :action_text,
            input_html: { rows: 5 })
          f.input :member_form_extra_text_only, as: :boolean
          translated_input(f, :member_form_complements_texts,
            hint: t("formtastic.hints.organization.member_form_complements_text"),
            required: false,
            as: :action_text,
            input_html: { rows: 5 })
          f.input :member_form_complement_quantities, as: :boolean
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

          li class: "subtitle" do
            h2 t("members.members.new.more_info")
          end
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

          li class: "subtitle" do
            h2 t(".documents_to_validate")
            span t(".documents_to_validate_hint")
          end
          translated_input(f, :charter_urls, required: false)
          translated_input(f, :statutes_urls, required: false)
          translated_input(f, :terms_of_service_urls, required: false)
          translated_input(f, :privacy_policy_urls, required: false)

          para class: "mt-4 flex justify-center" do
            a href: new_members_member_url(subdomain: Current.org.members_subdomain), class: "btn btn-sm btn-light" do
              span icon("arrow-top-right-on-square", class: "size-5 me-1", title: t("active_admin.site_footer.handbook"))
              span t(".registration_form")
            end.html_safe
          end
        end
        tab t(".member_account"), id: "member_account" do
          translated_input(f, :member_information_texts,
            hint: t("formtastic.hints.organization.member_information_text"),
            required: false,
            as: :action_text,
            input_html: { class: "long-text" })
          translated_input(f, :member_information_titles,
            hint: t("formtastic.hints.organization.member_information_title"),
            required: false,
            input_html: { placeholder: t("members.information.default_title") })
        end
        tab Membership.model_name.human, id: "membership" do
          para t(".membership_update_text_html"), class: "description"

          f.input :membership_depot_update_allowed
          f.input :membership_complements_update_allowed
          translated_input(f, :membership_update_texts,
            as: :action_text,
            required: false,
            hint: t("formtastic.hints.organization.membership_update_text"))

          f.input :basket_update_limit_in_days, step: 1
        end
        tab t(".membership_renewal"), id: "membership_renewal" do
          para t(".membership_renewal_text_html"), class: "description"
          translated_input(f, :open_renewal_texts,
            as: :action_text,
            required: false,
            hint: t("formtastic.hints.organization.open_renewal_text"))
          f.input :open_renewal_reminder_sent_after_in_days
          f.input :membership_renewed_attributes,
            as: :check_boxes,
            wrapper_html: { class: "single-column" },
            toggle_all: false,
            collection: membership_renewed_attributes_collection
          f.input :membership_renewal_depot_update

          handbook_button(self, "membership_renewal")
        end
        tab Delivery.human_attribute_name(:sheets), id: "pdf-sheets" do
          para t(".delivery_sheets_text_html"), class: "description"
          translated_input(f, :delivery_pdf_footers, required: false)


          f.input :delivery_pdf_member_info,
            as: :radio,
            collection: Organization::DELIVERY_PDF_MEMBER_INFOS.map { |info|
              [
                content_tag(:span, t("organization.delivery_pdf_member_info.#{info}")),
                info
              ]
            }
        end
        tab t(".mailer"), id: "mail"  do
          para t(".mailer_text_html"), class: "description"
          f.input :email_default_from,
            as: :string,
            hint: t("formtastic.hints.organization.email_default_from_html", domain: Current.org.domain)
          translated_input(f, :email_signatures,
            as: :text,
            required: true,
            input_html: { rows: 2 })
          translated_input(f, :email_footers,
            as: :text,
            required: true,
            input_html: { rows: 3 })
        end
      end
    end

    f.input :features,
      as: :check_boxes,
      wrapper_html: {
        class: "features-list single-column",
        data: { controller: "features-list" }
        },
      toggle_all: false,
      collection: all_features.map { |ff|
        [
          content_tag(:span, class: "ms-4") {
            content_tag(:h3, t("features.#{ff}"), class: "font-medium") +
            content_tag(:span, t("features.#{ff}_hint").html_safe, class: "text-gray-500 dark:text-gray-400")
          },
          ff,
          data: { action: "features-list#toggleTab" }
        ]
      }

    f.inputs do
      tabs id: "features" do
        tab "", selected: true, hidden: true, id: "none" do
          para t(".no_features_selected"), class: "text-gray-500 italic text-center"
        end
        tab Absence.model_name.human, id: "absence", hidden: !feature?("absence"), selected: feature?("absence"), data: { controller: "form-disabler" } do
          translated_input(f, :absence_extra_texts,
            hint: t("formtastic.hints.organization.absence_extra_text"),
            required: false,
            as: :action_text,
            input_html: { rows: 5 })
          f.input :absence_extra_text_only, as: :boolean

          f.input :absences_billed,
            input_html: { data: { action: "form-disabler#toggleInputs" } }
          f.input :absence_notice_period_in_days, min: 1, required: true

          f.input :basket_shifts_annually,
            hint: t("formtastic.hints.organization.basket_shifts_annually_html"),
            input_html: {
              data: { form_disabler_target: "input", default_value: f.object.basket_shifts_annually },
              disabled: !f.object.absences_billed?
            }

          f.input :basket_shift_deadline_in_weeks,
            hint: t("formtastic.hints.organization.basket_shift_deadline_in_weeks_html"),
            input_html: {
              data: { form_disabler_target: "input", default_value: f.object.basket_shift_deadline_in_weeks },
              disabled: !f.object.absences_billed?
            }

          handbook_button(self, "absences")
        end

        tab BiddingRound.model_name.human, id: "bidding_round", hidden: !feature?("bidding_round"), selected: feature?("bidding_round"), data: { controller: "form-disabler" } do
          f.input :bidding_round_basket_size_price_min_percentage, min: 0, max: 100, step: 1
          f.input :bidding_round_basket_size_price_max_percentage, min: 0, step: 1
          f.input :open_bidding_round_reminder_sent_after_in_days

          handbook_button(self, "bidding_round")
        end

        tab t(".shop"), id: "shop", hidden: !feature?("shop"), selected: feature?("shop") do
          f.input :shop_admin_only
          translated_input(f, :shop_texts,
            as: :action_text,
            required: false,
            hint: t("formtastic.hints.organization.shop_text"))
          translated_input(f, :shop_terms_of_sale_urls,
            required: false,
            hint: t("formtastic.hints.organization.shop_terms_of_sale_url"))
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
            hint: t("formtastic.hints.organization.shop_invoice_info"),
            required: false)
          translated_input(f, :shop_delivery_pdf_footers, required: false)

          handbook_button(self, "shop")
        end
        tab t(".members_participation"), id: "activity", hidden: !feature?("activity"), selected: feature?("activity") do
          f.input :activity_i18n_scope,
            as: :select,
            collection: Organization.activity_i18n_scopes.map { |s| [ t("activities.#{s}", count: 2), s ] },
            prompt: true
          f.input :activity_price
          f.input :activity_participations_form_min
          f.input :activity_participations_form_max
          f.input :activity_participations_form_step, input_html: { min: 1 }
          translated_input(f, :activity_participations_form_details,
            hint: t("formtastic.hints.organization.activity_participations_demanded_annually_form_detail"),
            required: false,
            placeholder: ->(locale) {
              I18n.with_locale(locale) {
                activity_participations_form_detail(force_default: true)
              }
            })
          f.input :activity_participations_demanded_logic,
            as: :text,
            hint: t("formtastic.hints.organization.activity_participations_demanded_logic_html"),
            input_html: {
              data: { mode: "liquid", code_editor_target: "editor" }
            }

          f.input :activity_availability_limit_in_days, required: true
          f.input :activity_participation_deletion_deadline_in_days
          f.input :activity_phone, as: :phone,
            hint: t("formtastic.hints.organization.activity_phone_html")

          handbook_button(self, "activity")
        end
        tab t("features.new_member_fee"), id: "new_member_fee", hidden: !feature?("new_member_fee"), selected: feature?("new_member_fee") do
          translated_input(f, :new_member_fee_descriptions,
            required: true,
            label: ->(_) { InvoiceItem.human_attribute_name(:description) },
            hint: t("formtastic.hints.organization.new_member_fee_description"))
          f.input :new_member_fee,
            required: true,
            min: 0,
            step: 0.05,
            label: InvoiceItem.human_attribute_name(:amount)

          handbook_button(self, "new_member_fee")
        end
        tab Organization.human_attribute_name(:basket_price_extra), id: "basket_price_extra", hidden: !feature?("basket_price_extra"), selected: feature?("basket_price_extra") do
          translated_input(f, :basket_price_extra_titles, required: false)
          translated_input(f, :basket_price_extra_public_titles,
            hint: t("formtastic.hints.organization.basket_price_extra_public_title"),
            required: false)
          translated_input(f, :basket_price_extra_texts,
            hint: t("formtastic.hints.organization.basket_price_extra_text"),
            required: false,
            as: :action_text,
            input_html: { rows: 5 })
          f.input :basket_price_extras,
            as: :string,
            input_html: { value: f.object.basket_price_extras }
          translated_input(f, :basket_price_extra_labels,
            as: :text,
            hint: t("formtastic.hints.organization.basket_price_extra_labels_html"),
            input_html: {
              data: { mode: "liquid", code_editor_target: "editor" }
            })
          translated_input(f, :basket_price_extra_label_details,
            as: :text,
            placeholder: Current.org.basket_price_extra_label_detail_default,
            hint: t("formtastic.hints.organization.basket_price_extra_label_details_html"),
            input_html: {
              data: { mode: "liquid", code_editor_target: "editor" }
            })

          f.input :basket_price_extra_dynamic_pricing,
            as: :text,
            hint: t("formtastic.hints.organization.basket_price_extra_dynamic_pricing_html"),
            input_html: {
              data: { mode: "liquid", code_editor_target: "editor" }
            }

          handbook_button(self, "basket_price_extra")
        end
        tab t("features.local_currency"), id: "local_currency", hidden: !feature?("local_currency"), selected: feature?("local_currency") do
          f.input :local_currency_code,
            collection: locale_currencies_collection,
            include_blank: false,
            required: false
          f.input :local_currency_identifier, required: true
          f.input :local_currency_wallet, required: true
          f.input :local_currency_secret,
            required: true,
            as: :password,
            input_html: { value: "*" * resource.local_currency_secret&.length.to_i }
          handbook_button(self, "local_currency")
        end
      end
    end

    f.actions do
      f.submit t("active_admin.resources.organization.submit")
    end
  end

  permit_params \
    :name, :host,
    :url, :logo, :email, :phone,
    :email_default_from, :email_footer,
    :trial_baskets_count,
    :iban, :sepa_creditor_identifier, :bank_reference, :creditor_name,
    :creditor_street, :creditor_city, :creditor_zip,
    :annual_fee, :annual_fee_member_form, :annual_fee_support_member_only,
    :share_price, :shares_number,
    :activity_i18n_scope, :activity_participation_deletion_deadline_in_days,
    :activity_availability_limit_in_days, :activity_price, :activity_phone,
    :activity_participations_form_min, :activity_participations_form_max,
    :activity_participations_form_step,
    :activity_participations_demanded_logic,
    :vat_number, :vat_membership_rate, :vat_activity_rate, :vat_shop_rate,
    :absences_billed, :absence_extra_text_only,
    :absence_notice_period_in_days,
    :basket_shifts_annually, :basket_shift_deadline_in_weeks,
    :bidding_round_basket_size_price_min_percentage, :bidding_round_basket_size_price_max_percentage,
    :open_bidding_round_reminder_sent_after_in_days,
    :delivery_pdf_member_info,
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
    :member_form_extra_text_only, :member_form_complement_quantities,
    :basket_sizes_member_order_mode, :basket_complements_member_order_mode,
    :depots_member_order_mode, :delivery_cycles_member_order_mode,
    :basket_price_extras,
    :member_profession_form_mode, :member_come_from_form_mode,
    :membership_depot_update_allowed, :membership_complements_update_allowed,
    :basket_update_limit_in_days,
    :basket_price_extra_dynamic_pricing,
    :new_member_fee,
    :social_network_urls,
    :local_currency_code, :local_currency_identifier, :local_currency_wallet, :local_currency_secret,
    *I18n.available_locales.map { |l| "invoice_document_name_#{l}" },
    *I18n.available_locales.map { |l| "invoice_info_#{l}" },
    *I18n.available_locales.map { |l| "invoice_sepa_info_#{l}" },
    *I18n.available_locales.map { |l| "invoice_footer_#{l}" },
    *I18n.available_locales.map { |l| "email_signature_#{l}" },
    *I18n.available_locales.map { |l| "email_footer_#{l}" },
    *I18n.available_locales.map { |l| "delivery_pdf_footer_#{l}" },
    *I18n.available_locales.map { |l| "charter_url_#{l}" },
    *I18n.available_locales.map { |l| "statutes_url_#{l}" },
    *I18n.available_locales.map { |l| "terms_of_service_url_#{l}" },
    *I18n.available_locales.map { |l| "privacy_policy_url_#{l}" },
    *I18n.available_locales.map { |l| "member_form_subtitle_#{l}" },
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
    invoice_logos: [],
    billing_year_divisions: [],
    features: [],
    membership_renewed_attributes: []

  controller do
    include TranslatedCSVFilename
    include FormsHelper

    defaults singleton: true

    def resource
      @resource ||= Current.org
    end
  end
end
