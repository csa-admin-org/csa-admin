# frozen_string_literal: true

module Demo::Seeder::Organization
  extend ActiveSupport::Concern

  private

  def reset_organization_settings!
    log "Resetting organization settings..."

    org = ::Organization.instance
    org.update!(organization_reset_attributes)
    org.send(:set_defaults)
    org.send(:set_basket_price_extra_defaults)
    org.save!
    clear_organization_rich_texts!(org)
  end

  def organization_reset_attributes
    {
      name: "CSA Admin Demo",
      features: demo_enabled_features,
      languages: [ @org_language ],
      basket_i18n_scopes: demo_basket_i18n_scopes,
      phone: nil,
      email: "info@csa-admin.org",
      email_default_from: "info@#{@org_domain}",
      creditor_name: creditor_info[:name],
      creditor_street: creditor_info[:street],
      creditor_zip: creditor_info[:zip],
      creditor_city: creditor_info[:city],
      country_code: germany? ? "DE" : "CH",
      currency_code: germany? ? "EUR" : "CHF",
      **billing_reset_attributes,
      **registration_reset_attributes,
      **membership_reset_attributes,
      **feature_reset_attributes
    }
  end

  def demo_enabled_features
    excluded = %i[annual_fee local_currency member_information new_member_fee shares vat]
    excluded << :sepa unless germany?
    excluded << :bidding_round unless germany?
    (::Organization::FEATURES - excluded).map(&:to_s)
  end

  def demo_basket_i18n_scopes
    {
      "fr" => "basket",
      "de" => "share",
      "it" => "basket",
      "nl" => "package",
      "en" => "basket"
    }
  end

  def billing_reset_attributes
    {
      recurring_billing_wday: 1,
      billing_year_divisions: [ 1, 4, 12 ],
      trial_baskets_count: 2,
      send_closed_invoice: false,
      billing_starts_after_first_delivery: false,
      billing_ends_on_last_delivery_fy_month: false,
      sepa_creditor_identifier: germany? ? "DE98ZZZ09999999999" : nil,
      bank_reference: nil,
      iban: germany? ? "DE87200500001234567890" : "CH5530024123456789012",
      invoice_sepa_info: germany? ? "Der Betrag wird per SEPA-Lastschrift eingezogen." : nil,
      invoice_document_names: {},
      invoice_membership_summary_only: false,
      vat_number: nil,
      vat_membership_rate: nil,
      vat_activity_rate: nil,
      vat_shop_rate: nil,
      annual_fee: nil,
      annual_fee_member_form: false,
      annual_fee_support_member_only: false,
      share_price: nil,
      shares_number: nil
    }
  end

  def registration_reset_attributes
    {
      member_form_extra_text_only: false,
      member_form_complement_quantities: false,
      basket_sizes_member_order_mode: "price_desc",
      basket_complements_member_order_mode: "deliveries_count_desc",
      depots_member_order_mode: "price_asc",
      delivery_cycles_member_order_mode: "deliveries_count_desc",
      allow_alternative_depots: false,
      member_profession_form_mode: "visible",
      member_come_from_form_mode: "visible",
      charter_urls: {},
      statutes_urls: {},
      privacy_policy_url: {},
      terms_of_service_url: "https://csa-admin.org",
      member_information_titles: {},
      social_network_urls: ""
    }
  end

  def membership_reset_attributes
    {
      membership_depot_update_allowed: false,
      membership_complements_update_allowed: false,
      basket_update_limit_in_days: 0,
      open_renewal_reminder_sent_after_in_days: nil,
      membership_renewed_attributes: %w[
        baskets_annual_price_change
        basket_complements_annual_price_change
        activity_participations
        absences_included_annually
      ],
      membership_renewal_depot_update: true,
      delivery_pdf_footers: {},
      delivery_pdf_member_info: "none",
      delivery_pdf_member_name_format: "none",
      basket_content_delivery_pdf_visible: false
    }
  end

  def feature_reset_attributes
    {
      absences_billed: true,
      absence_notice_period_in_days: 7,
      absence_extra_text_only: false,
      basket_shifts_annually: 0,
      basket_shift_deadline_in_weeks: 4,
      absences_included_mode: "provisional_absence",
      absences_included_reminder_weeks_before: 4,
      absences_included_logic: ::Organization::AbsenceFeature::ABSENCES_INCLUDED_LOGIC_DEFAULT,
      activity_i18n_scope: "halfday_work",
      activity_price: 60,
      activity_participations_form_min: nil,
      activity_participations_form_max: nil,
      activity_participations_form_step: 1,
      activity_participations_form_details: {},
      activity_participations_demanded_logic: ::Organization::ActivityFeature::ACTIVITY_PARTICIPATIONS_DEMANDED_LOGIC_DEFAULT,
      activity_availability_limit_in_days: 3,
      activity_participation_deletion_deadline_in_days: nil,
      activity_phone: nil,
      basket_price_extras: "0, 2, 4, 6",
      basket_price_extra_titles: translated_text("Solidarity price"),
      basket_price_extra_public_titles: translated_text("Solidarity"),
      basket_price_extra_texts: {},
      basket_price_extra_label_details: {},
      basket_price_extra_dynamic_pricing: nil,
      bidding_round_basket_size_price_min_percentage: germany? ? 50 : 0,
      bidding_round_basket_size_price_max_percentage: germany? ? 50 : 100,
      open_bidding_round_reminder_sent_after_in_days: germany? ? 7 : nil,
      shop_admin_only: false,
      shop_order_maximum_weight_in_kg: nil,
      shop_order_minimal_amount: nil,
      shop_member_percentages: "",
      shop_delivery_open_delay_in_days: nil,
      shop_delivery_open_last_day_end_time: nil,
      shop_order_automatic_invoicing_delay_in_days: nil,
      shop_invoice_infos: {},
      shop_delivery_pdf_footers: {},
      shop_terms_of_sale_urls: {}
    }
  end

  def creditor_info
    Demo::Seeder::CREDITOR_INFO.fetch(@org_language)
  end

  def germany?
    @org_language == "de"
  end

  def clear_organization_rich_texts!(org)
    rich_text_fields = %i[
      open_renewal_text
      membership_update_text
      member_information_text
      member_form_subtitle
      member_form_extra_text
      member_form_complements_text
      member_form_activity_participations_text
      absence_extra_text
      shop_text
    ]

    ::Organization.languages.each do |locale|
      rich_text_fields.each do |field|
        rich_text = org.send("#{field}_#{locale}")
        rich_text.body = nil if rich_text.present?
      end
    end

    org.save!
  end
end
