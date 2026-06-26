# frozen_string_literal: true

ActiveAdmin.register Organization do
  menu false

  actions :show, :edit, :update
  config.clear_action_items!

  breadcrumb do
    if params[:action].in? %w[edit update]
      [ link_to(t("active_admin.resources.organization.edit_model"), organization_path) ]
    else
      []
    end
  end

  show title: proc { t("active_admin.resources.organization.edit_model") } do |org|
    div class: "space-y-20", "data-controller" => "settings-anchor" do
      div class: "grid grid-cols-1 lg:grid-cols-2 md:auto-rows-fr gap-4" do
        organization_enabled_setting_sections(org).each do |section|
          div id: section[:key], class: "scroll-mt-16 h-full", "data-settings-anchor-highlight-target" => true do
            panel organization_setting_section_title(section),
              icon: section[:icon],
              action: organization_setting_section_actions(section, org),
              class: "h-full" do
              render partial: "active_admin/organization_settings/cards/#{section[:key]}",
                locals: { org: org, section: section, context: self }
            end
          end
        end
      end

      div id: "disabled-features", class: "scroll-mt-16 space-y-4", "data-settings-anchor-highlight-target" => true do
        h3 Organization.human_attribute_name(:features), class: "text-left text-3xl font-extralight mb-2"
        para t("active_admin.resources.organization.optional_features_description_html"), class: "text-gray-500 dark:text-gray-400"

        disabled_sections = organization_disabled_setting_sections(org)
        if disabled_sections.any?
          div class: "mt-6 space-y-4" do
            disabled_sections.each do |section|
              div id: section[:key], class: "scroll-mt-16", "data-settings-anchor-highlight-target" => true do
                panel organization_setting_section_title(section),
                  icon: section[:icon],
                  action: organization_disabled_setting_section_actions(section) do
                  div class: "flex flex-wrap gap-4 p-2 pt-0 justify-between items-center" do
                    para organization_disabled_setting_section_hint(section), class: "description"
                    if authorized?(:update, Organization)
                      div class: "grow text-right" do
                        text_node organization_disabled_setting_section_primary_action(section)
                      end
                    end
                  end
                end
              end
            end
          end
        else
          para t("active_admin.resources.organization.all_optional_features_configured"), class: "text-gray-500 italic text-center"
        end
      end
    end
  end

  form title: proc { organization_setting_section_title(settings_section) },
    html: { novalidate: true },
    data: { controller: "code-editor", turbo: false } do |f|
    section = settings_section

    text_node hidden_field_tag(:section, section[:key])

    f.semantic_errors :base

    if organization_setting_section_feature?(section)
      render partial: "active_admin/organization_settings/forms/activation",
        locals: { f: f, section: section, context: self }
    end

    render partial: "active_admin/organization_settings/forms/#{section[:key]}",
      locals: { f: f, section: section, context: self }

    f.actions do
      f.action :submit, label: t("active_admin.resources.organization.submit")
      cancel_link organization_path(anchor: section[:key])
    end
  end

  permit_params \
    :name, :host,
    :url, :logo, :email, :phone,
    :email_default_from, :email_footer,
    *I18n.available_locales.map { |l| "basket_i18n_scope_#{l}" },
    :trial_baskets_count,
    :maps_style,
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
    :absences_included_mode, :absences_included_reminder_weeks_before,
    :basket_shifts_annually, :basket_shift_deadline_in_weeks,
    :bidding_round_basket_size_price_min_percentage, :bidding_round_basket_size_price_max_percentage,
    :open_bidding_round_reminder_sent_after_in_days,
    :delivery_pdf_member_info,
    :delivery_pdf_member_name_format,
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
    :basket_content_delivery_pdf_visible,
    :basket_content_member_visible,
    :basket_content_member_visible_hours_before,
    :basket_content_member_display_quantity,
    :basket_content_member_display_product_url,
    :basket_price_extras,
    :member_profession_form_mode, :member_come_from_form_mode,
    :membership_depot_update_allowed, :membership_complements_update_allowed,
    :basket_update_limit_in_days,
    :basket_price_extra_dynamic_pricing,
    :new_member_fee,
    :invoice_membership_summary_only,
    :social_network_urls,
    :local_currency_code, :local_currency_membership_annual_fee_only, :local_currency_identifier, :local_currency_wallet, :local_currency_secret,
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
    *I18n.available_locales.map { |l| "member_form_activity_participations_text_#{l}" },
    *I18n.available_locales.map { |l| "member_form_delivery_cycle_label_#{l}" },
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
    *I18n.available_locales.map { |l| "basket_content_member_title_#{l}" },
    *I18n.available_locales.map { |l| "basket_content_member_note_#{l}" },
    *I18n.available_locales.map { |l| "new_member_fee_description_#{l}" },
    *I18n.available_locales.map { |l| "activity_participations_form_detail_#{l}" },
    invoice_logos: [],
    billing_year_divisions: [],
    features: [],
    membership_renewed_attributes: []

  controller do
    include TranslatedCSVFilename
    include ActivitiesHelper
    include FormsHelper
    include OrganizationsHelper
    include ActiveAdmin::OrganizationSettingsHelper

    defaults singleton: true

    helper_method :settings_section, :settings_section_key

    before_action :ensure_settings_section!, only: %i[edit update]
    before_action :ensure_editable_settings_section!, only: :edit

    def resource
      @resource ||= Current.org
    end

    def update
      update! do |success, failure|
        success.html { redirect_to organization_path(anchor: settings_section_key) }
        failure.html { render :edit, status: :unprocessable_entity }
      end
    end

    def settings_section_key
      params[:section].presence || params.dig(:organization, :settings_section).presence
    end

    def settings_section
      @settings_section ||= organization_setting_section(settings_section_key)
    end

    private

    def ensure_settings_section!
      return if settings_section && organization_setting_section_available?(settings_section, resource)

      redirect_to organization_path
    end

    def ensure_editable_settings_section!
      return if performed?
      return if organization_setting_section_editable?(settings_section)

      redirect_to organization_path(anchor: settings_section_key)
    end
  end
end
