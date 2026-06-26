# frozen_string_literal: true

require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "read-only admins can view settings overview without edit links" do
    login admins(:external)

    get organization_path

    assert_response :success
    assert_includes response.body, 'id="general"'
    assert_includes response.body, 'id="disabled-features"'
    assert_select "[data-controller~='settings-anchor']"
    assert_select "#delivery_sheets[data-settings-anchor-highlight-target]"
    assert_select "#disabled-features[data-settings-anchor-highlight-target]"
    assert_not_includes response.body, edit_organization_path(:general)
  end

  test "superadmins can access focused edit links from settings overview" do
    login admins(:super)

    get organization_path

    assert_response :success
    assert_includes response.body, edit_organization_path(:general)
    assert_includes response.body, edit_organization_path(:billing)
  end

  test "general settings overview links to website from panel action and shows social networks" do
    Current.org.update!(social_network_urls: "https://instagram.com/acme")
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#general .row-url", false
    assert_select "#general .panel-actions a[href='#{Current.org.url}']"
    assert_select "#general a[href='https://instagram.com/acme'] svg"
  end

  test "general settings overview marks social networks as unconfigured" do
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#general [data-status='unconfigured']",
      text: I18n.t("active_admin.resources.organization.not_configured", locale: admins(:super).language)
  end

  test "settings overview keeps core sections first and sorts enabled optional sections by title" do
    org(features: [ "shop", "activity", "absence" ])
    login admins(:super)

    get organization_path

    assert_response :success
    section_ids = css_select(".panel").map { |panel| panel.parent["id"] }.compact
    optional_ids = %w[absence activity shop]
    actual_optional_ids = section_ids.select { |id| id.in?(optional_ids) }
    expected_optional_ids = optional_ids.sort_by { |id|
      I18n.transliterate(css_select("##{id} .panel-title").text.squish.downcase)
    }

    assert_equal %w[general mailer], section_ids.first(2)
    assert_operator section_ids.index("mailer"), :<, section_ids.index(actual_optional_ids.first)
    assert_equal expected_optional_ids, actual_optional_ids
  end

  test "restricted settings are hidden from disabled features until activated" do
    login admins(:ultra)

    get organization_path

    assert_response :success
    assert_select "#disabled-features #maps", false

    org(features: Current.org.features | [ :maps ])
    get organization_path

    assert_response :success
    assert_select "#maps .panel-title", text: I18n.t("features.maps", locale: admins(:ultra).language)
    assert_select "#disabled-features #maps", false
  end

  test "enabled maps feature shows decimal depot coordinates to regular admins" do
    org(features: Current.org.features | [ :maps ])
    login admins(:super)

    get edit_depot_path(depots(:farm))

    assert_response :success
    assert_select "#depot_maps_visible"
    assert_select "#depot_latitude"
    assert_select "#depot_longitude"
  end

  test "activity settings title uses generic feature name until activated" do
    locale = admins(:super).language
    activity_title = I18n.t("activities.#{Current.org.activity_i18n_scope}", count: 2, locale: locale)
    feature_title = I18n.t("features.activity", locale: locale)
    org(features: [])
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#disabled-features #activity .panel-title", text: feature_title
    assert_select "#disabled-features #activity .panel-title", text: activity_title, count: 0

    org(features: [ "activity" ])
    get organization_path

    assert_response :success
    assert_select "#activity .panel-title", text: activity_title
  end

  test "mailer settings overview shows current language footer text" do
    locale = admins(:super).language
    other_locale = (Current.org.languages - [ locale ]).first || "fr"
    Current.org.update_columns(
      languages: [ locale, other_locale ],
      email_footers: {
        locale => "Reply to this email.\nAcme, Nowhere 42",
        other_locale => "Other language footer"
      })
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#mailer .panel-actions a[href='#{handbook_page_path("emails", anchor: "email-settings")}']"
    assert_select "#mailer tr[data-row='email_signature']", false
    assert_select "#mailer tr[data-row='email_footer'] p.text-sm.text-center", text: /Reply to this email\.\s*Acme, Nowhere 42/
    assert_select "#mailer", text: /Other language footer/, count: 0
  end

  test "settings overview lists membership renewal attributes and ignores blank values" do
    org(membership_renewed_attributes: [ "", "baskets_annual_price_change", "activity_participations" ])
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#membership_renewal tr[data-row='open_renewal_text']", false
    assert_select "#membership_renewal tr[data-row='membership_renewed_attributes'] li", 2
    assert_select "#membership_renewal tr[data-row='membership_renewed_attributes'] li",
      text: Membership.human_attribute_name(:baskets_annual_price_change)
  end

  test "billing settings overview shows disabled recurring billing and fiscal-year period" do
    travel_to "2024-06-01"
    org(
      recurring_billing_wday: nil,
      fiscal_year_start_month: 4,
      billing_starts_after_first_delivery: false,
      billing_ends_on_last_delivery_fy_month: false)
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#billing [data-status='disabled']",
      text: I18n.t("active_admin.resource.form.recurring_billing_disabled", locale: admins(:super).language)
    assert_select "#billing", text: /#{I18n.t("active_admin.resources.organization.billing_period", locale: admins(:super).language)}/
    assert_select "#billing", text: /April\s+–\s+March/
    assert_select "#billing", text: /#{Organization.human_attribute_name(:billing_year_divisions, locale: admins(:super).language)}/
    assert_select "#billing .row-send_closed_invoice", false
  end

  test "billing settings overview uses next fiscal year deliveries for period when present" do
    travel_to "2024-06-01"
    org(
      fiscal_year_start_month: 4,
      billing_starts_after_first_delivery: true,
      billing_ends_on_last_delivery_fy_month: true)
    deliveries = Delivery.during_year(Current.fy_year + 1).to_a
    deliveries.each_with_index do |delivery, index|
      delivery.update_column(:date, Date.new(2026, 2, 1) + index.days)
    end
    deliveries.each_with_index do |delivery, index|
      delivery.update_column(:date, Date.new(2025, 5, 1) + index.days)
    end
    deliveries.last.update_column(:date, Date.new(2025, 12, 1))
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#billing", text: /May\s+–\s+December/
  end

  test "invoice settings overview shows iban address and label placeholder" do
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#invoice .panel-actions a[href='#{handbook_page_path("billing", anchor: "invoice-settings")}']"
    assert_select "#invoice", text: /#{Current.org.iban_type_name}/
    assert_select "#invoice", text: /#{Regexp.escape(Current.org.iban_formatted)}/
    assert_select "#invoice", text: /#{I18n.t("attributes.address", locale: admins(:super).language)}/
    assert_select "#invoice", text: /Acme/
    assert_select "#invoice", text: /Nowhere 42/
    assert_select "#invoice", text: /1234 City/
    assert_select "#invoice", text: /#{Organization.human_attribute_name(:invoice_logos, locale: admins(:super).language)}/
    assert_select "#invoice .attributes-table-empty-value", text: I18n.t("active_admin.empty", locale: admins(:super).language)
    assert_select "#invoice .row-creditor-name", false
    assert_select "#invoice .row-invoice-infos", false
  end

  test "invoice settings overview escapes creditor address" do
    Current.org.update!(
      creditor_name: "<script>alert('xss')</script>",
      creditor_street: "<b>Main Street</b>",
      creditor_city: "<img src=x>",
      creditor_zip: "1234")
    login admins(:super)

    get organization_path

    assert_response :success
    assert_includes response.body, "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    assert_includes response.body, "&lt;b&gt;Main Street&lt;/b&gt;"
    assert_includes response.body, "1234 &lt;img src=x&gt;"
    assert_not_includes response.body, "<script>alert('xss')</script>"
    assert_not_includes response.body, "<b>Main Street</b>"
  end

  test "registration settings overview keeps a compact member-facing summary" do
    locale = admins(:super).language
    Current.org.update!(
      member_form_complement_quantities: true,
      allow_alternative_depots: true,
      member_profession_form_mode: "visible",
      member_come_from_form_mode: "required",
      "member_form_extra_text_#{locale}" => "Welcome text",
      "member_form_complements_text_#{locale}" => "Complements text",
      "charter_url_#{locale}" => "https://example.org/charter.pdf",
      "statutes_url_#{locale}" => nil,
      "terms_of_service_url_#{locale}" => nil,
      "privacy_policy_url_#{locale}" => "https://example.org/privacy.pdf")
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#registration .panel-actions a[href='#{new_members_member_url(subdomain: Current.org.members_subdomain)}']"
    assert_select "#registration tr[data-row='member_form_mode']", false
    assert_select "#registration .attributes-table a[href='#{new_members_member_url(subdomain: Current.org.members_subdomain)}']", false
    assert_select "#registration tr[data-row='member_form_complement_quantities'] [data-status='yes']"
    assert_select "#registration tr[data-row='allow_alternative_depots'] [data-status='yes']"
    assert_select "#registration", text: /#{Regexp.escape(Member.human_attribute_name(:profession, locale: locale))}/
    assert_select "#registration", text: /#{Regexp.escape(Member.human_attribute_name(:come_from, locale: locale))}/
    assert_select "#registration [data-status='visible']", text: I18n.t("form_modes.visible", locale: locale)
    assert_select "#registration [data-status='required']", text: I18n.t("form_modes.required", locale: locale)
    assert_select "#registration", text: /#{Regexp.escape(I18n.t("active_admin.resource.form.documents_to_validate", locale: locale))}/
    assert_select "#registration a[href='https://example.org/charter.pdf']", text: I18n.t("members.members.new.documents.charter", locale: locale)
    assert_select "#registration a[href='https://example.org/privacy.pdf']", text: I18n.t("members.members.new.documents.privacy_policy", locale: locale)
    assert_select "#registration tr[data-row='member_form_extra_text']", false
    assert_select "#registration tr[data-row='member_form_complements_text']", false
    assert_select "#registration tr[data-row='basket_sizes_member_order_mode']", false
  end

  test "converted optional settings stay disabled when only stale values are configured" do
    org(
      features: [],
      annual_fee: 42,
      share_price: 100,
      shares_number: 3,
      vat_number: "CHE-103.987.077",
      vat_membership_rate: 2.6,
      country_code: "DE",
      sepa_creditor_identifier: "DE98ZZZ09999999999",
      member_information_titles: { "en" => "Member News" })
    login admins(:super)

    get organization_path

    assert_response :success
    %w[annual_fee member_information shares vat sepa].each do |section|
      assert_select "#disabled-features ##{section}"
    end
  end

  test "member information page is listed as disabled when no text is configured" do
    locale = admins(:super).language
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#disabled-features #member_information .panel-title",
      text: I18n.t("active_admin.resource.form.member_information_page", locale: locale)
    assert_select "#disabled-features #member_information", text: /#{Regexp.escape(I18n.t("features.member_information_hint", locale: locale))}/
    assert_select "#disabled-features #member_information a[href='#{edit_organization_path(:member_information, activate: true)}']"
  end

  test "member information page overview shows description and title when enabled" do
    locale = admins(:super).language
    Current.org.update!(
      features: Current.org.features | [ "member_information" ],
      "member_information_title_#{locale}" => "Member News",
      "member_information_text_#{locale}" => "Confidential member text")
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#member_information .panel-title",
      text: I18n.t("active_admin.resource.form.member_information_page", locale: locale)
    assert_select "#member_information", text: /#{Regexp.escape(I18n.t("features.member_information_hint", locale: locale))}/
    assert_select "#member_information tr[data-row='member_information_title']", text: /Member News/
    assert_select "#member_information tr[data-row='member_information_text']", false
    assert_select "#disabled-features #member_information", false
  end

  test "annual fee disabled card uses dedicated feature hint" do
    locale = admins(:super).language
    org(
      features: (Current.org.features - [ :annual_fee ]).map(&:to_s),
      annual_fee: nil,
      annual_fee_member_form: false,
      annual_fee_support_member_only: false)
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#disabled-features #annual_fee", text: /#{Regexp.escape(I18n.t("features.annual_fee_hint", locale: locale))}/
    assert_select "#disabled-features #annual_fee", text: /#{Regexp.escape(I18n.t("formtastic.hints.organization.annual_fee", locale: locale))}/, count: 0
    assert_select "#disabled-features #annual_fee a[href='#{edit_organization_path(:annual_fee, activate: true)}']"
  end

  test "annual fee overview shows amount and visibility flags" do
    locale = admins(:super).language
    org(
      annual_fee: 42,
      annual_fee_support_member_only: true,
      annual_fee_member_form: false)
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#annual_fee", text: /#{Regexp.escape(I18n.t("features.annual_fee_hint", locale: locale))}/, count: 0
    assert_select "#annual_fee", text: /#{Regexp.escape(I18n.t("formtastic.hints.organization.annual_fee", locale: locale))}/, count: 0
    assert_select "#annual_fee tr[data-row='annual_fee']", text: /42/
    assert_select "#annual_fee tr[data-row='annual_fee_support_member_only'] [data-status='yes']"
    assert_select "#annual_fee tr[data-row='annual_fee_member_form'] [data-status='no']"
    assert_select "#disabled-features #annual_fee", false
  end

  test "annual fee edit page keeps side-effect hint visible" do
    locale = admins(:super).language
    org(annual_fee: 42)
    login admins(:super)

    get edit_organization_path(:annual_fee)

    assert_response :success
    assert_select "fieldset.inputs", text: /#{Regexp.escape(I18n.t("formtastic.hints.organization.annual_fee", locale: locale))}/
    assert_select "#organization_annual_fee"
    assert_select "#organization_annual_fee_support_member_only"
    assert_select "#organization_annual_fee_member_form"
  end

  test "shares disabled card uses feature hint" do
    locale = admins(:super).language
    org(share_price: nil, shares_number: nil)
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#disabled-features #shares", text: /#{Regexp.escape(I18n.t("features.shares_hint", locale: locale))}/
    assert_select "#disabled-features #shares a[href='#{edit_organization_path(:shares, activate: true)}']"
  end

  test "shares overview shows price and required number only when configured" do
    locale = admins(:super).language
    org(
      features: Current.org.features | [ :shares ],
      share_price: 100,
      shares_number: 3)
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#shares", text: /#{Regexp.escape(I18n.t("features.shares_hint", locale: locale))}/, count: 0
    assert_select "#shares .panel-actions a[href='#{handbook_page_path("billing", anchor: "share-capital")}']"
    assert_select "#shares tr[data-row='share_price']", text: /100/
    assert_select "#shares tr[data-row='shares_number']", text: /3/
    assert_select "#disabled-features #shares", false
  end

  test "shares edit page keeps price and required number in one settings fieldset" do
    login admins(:super)

    get edit_organization_path(:shares)

    assert_response :success
    fieldsets = css_select("fieldset.inputs")
    shares_fieldset = fieldsets.find { |fieldset|
      fieldset.to_html.include?("organization_share_price")
    }

    assert_equal 2, fieldsets.size
    assert shares_fieldset
    assert_includes shares_fieldset.to_html, "organization_share_price"
    assert_includes shares_fieldset.to_html, "organization_shares_number"
  end

  test "vat overview uses translated rate labels" do
    locale = "fr"
    admins(:super).update_column(:language, locale)
    org(
      features: Current.org.features | [ :vat ],
      vat_number: "CHE-103.987.077",
      vat_membership_rate: 2.6,
      vat_activity_rate: 8.1,
      vat_shop_rate: 2.6)
    login admins(:super)

    get organization_path

    membership_label = Membership.model_name.human(count: 2, locale: locale)
    activity_label = I18n.t("activities.#{Current.org.activity_i18n_scope}.other", locale: locale)
    shop_label = I18n.t("shop.title", locale: locale)

    assert_response :success
    assert_select "#vat th", text: membership_label
    assert_select "#vat th", text: activity_label
    assert_select "#vat th", text: shop_label
    assert_select "#vat", text: /\(en %\)/, count: 0
    assert_select "#vat", text: /Vat Membership Rate/, count: 0
    assert_select "#vat", text: /Vat Activity Rate/, count: 0
    assert_select "#vat", text: /Vat Shop Rate/, count: 0
  end

  test "sepa disabled card uses feature hint" do
    locale = admins(:super).language
    german_org(sepa_creditor_identifier: nil)
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#disabled-features #sepa", text: /#{Regexp.escape(I18n.t("features.sepa_hint", locale: locale))}/
    assert_select "#disabled-features #sepa .panel-actions a[href='#{handbook_page_path("sepa", anchor: "setup")}']"
    assert_select "#disabled-features #sepa", text: /supported countries/, count: 0
    assert_select "#disabled-features #sepa", text: /handbook/, count: 0
    assert_select "#disabled-features #sepa a[href='#{edit_organization_path(:sepa, activate: true)}']"
  end

  test "sepa overview shows current language invoice info text" do
    locale = "de"
    admins(:super).update_column(:language, locale)
    german_org(
      features: Current.org.features | [ :sepa ],
      sepa_creditor_identifier: "DE98ZZZ09999999999",
      invoice_membership_summary_only: true)
    Current.org.update_columns(
      invoice_sepa_infos: {
        "de" => "Der Betrag wird per SEPA-Lastschrift eingezogen.\nBitte Mandat prüfen.",
        "en" => "Other language SEPA info"
      })
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#sepa tr[data-row='invoice_sepa_info'] p.text-left.text-sm",
      text: /Der Betrag wird per SEPA-Lastschrift eingezogen\.\s*Bitte Mandat prüfen\./
    assert_select "#sepa tr[data-row='invoice_membership_summary_only'] [data-status='yes']"
    assert_select "#sepa", text: /Other language SEPA info/, count: 0
    assert_select "#disabled-features #sepa", false
  end

  test "membership updates settings overview focuses on member update controls" do
    locale = admins(:super).language
    Current.org.update!(basket_update_limit_in_days: 14)
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#membership_updates .panel-actions a[href='#{handbook_page_path("members", anchor: "membership-updates")}']"
    assert_select "#membership_updates .panel-title",
      text: I18n.t("active_admin.resource.form.membership_updates", locale: locale)
    assert_select "#membership_updates tr[data-row='membership_depot_update_allowed']"
    assert_select "#membership_updates tr[data-row='membership_complements_update_allowed']"
    assert_select "#membership_updates tr[data-row='basket_update_limit_in_days']", text: /14/
    assert_select "#membership_updates tr[data-row='membership_update_text']", false
  end

  test "membership updates edit page keeps all controls in one settings fieldset" do
    locale = admins(:super).language
    login admins(:super)

    get edit_organization_path(:membership_updates)

    assert_response :success
    fieldsets = css_select("fieldset.inputs")
    settings_fieldset = fieldsets.find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resources.organization.edit_model", locale: locale))
    }

    assert_equal 1, fieldsets.size
    assert settings_fieldset
    assert_includes settings_fieldset.to_html, "organization_membership_depot_update_allowed"
    assert_includes settings_fieldset.to_html, "organization_membership_complements_update_allowed"
    assert_includes settings_fieldset.to_html, "organization_basket_update_limit_in_days"
    assert_includes settings_fieldset.to_html, "organization_membership_update_text_#{locale}"
  end

  test "delivery sheets overview uses full title and empty footer placeholder when missing" do
    locale = admins(:super).language
    Current.org.update_columns(delivery_pdf_footers: {})
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#delivery_sheets .panel-title",
      text: I18n.t("active_admin.resource.form.delivery_sheets", locale: locale)
    assert_select "#delivery_sheets tr[data-row='#{Organization.human_attribute_name(:delivery_pdf_footer, locale: locale).parameterize(separator: "_")}'] .attributes-table-empty-value",
      text: I18n.t("active_admin.empty", locale: locale)
    assert_select "#delivery_sheets tr[data-row='delivery_pdf_footer']", false
    assert_select "#delivery_sheets tr[data-row='delivery_pdf_footers']", false
  end

  test "delivery sheets overview shows current language footer text when configured" do
    locale = admins(:super).language
    other_locale = (Current.org.languages - [ locale ]).first || "fr"
    Current.org.update_columns(
      languages: [ locale, other_locale ],
      delivery_pdf_footers: {
        locale => "Route de Cery 34\ncoordination@example.test",
        other_locale => "Other language footer"
      })
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#delivery_sheets tr[data-row='delivery_pdf_footer'] p.text-sm.text-center", text: /Route de Cery 34\s*coordination@example\.test/
    assert_select "#delivery_sheets tr[data-row='delivery_pdf_footers']", false
    assert_select "#delivery_sheets", text: /Other language footer/, count: 0
  end

  test "delivery sheets edit page keeps all controls in one fieldset" do
    locale = admins(:super).language
    login admins(:super)

    get edit_organization_path(:delivery_sheets)

    assert_response :success
    fieldsets = css_select("fieldset.inputs")
    delivery_sheets_fieldset = fieldsets.find { |fieldset|
      fieldset.to_html.include?("organization_delivery_pdf_member_info")
    }

    assert_equal 1, fieldsets.size
    assert delivery_sheets_fieldset
    assert_includes delivery_sheets_fieldset.to_html, "organization_delivery_pdf_member_info"
    assert_includes delivery_sheets_fieldset.to_html, "organization_delivery_pdf_member_name_format"
    assert_includes delivery_sheets_fieldset.to_html, "organization_delivery_pdf_footer_#{locale}"
  end

  test "settings overview renders missing optional amounts as not configured" do
    org(new_member_fee: nil, new_member_fee_descriptions: {})
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#new_member_fee" do |elements|
      card_html = elements.first.to_html
      assert_includes card_html, I18n.t("active_admin.resources.organization.not_configured", locale: admins(:super).language)
      assert_not_includes card_html, "0.00"
    end
  end

  test "new member fee overview shows translated description before amount" do
    locale = admins(:super).language
    description = "Registration admin fee"
    Current.org.update!(
      new_member_fee: 25,
      "new_member_fee_description_#{locale}" => description)
    login admins(:super)

    get organization_path

    assert_response :success
    rows = css_select("#new_member_fee tr")
    assert_match InvoiceItem.human_attribute_name(:description, locale: locale), rows[0].text
    assert_match description, rows[0].text
    assert_match InvoiceItem.human_attribute_name(:amount, locale: locale), rows[1].text
    assert_match(/25\.00/, rows[1].text)
  end

  test "shop overview hides admin only when disabled and formats opening cutoff" do
    locale = admins(:super).language
    org(features: Current.org.features | [ "shop" ])
    Current.org.update!(
      shop_admin_only: false,
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00"))
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#shop tr[data-row='shop_admin_only']", false
    assert_select "#shop",
      text: /#{Regexp.escape(I18n.t("active_admin.resource.form.shop_opening", count: 2, time: "12:00", locale: locale))}/

    Current.org.update!(shop_admin_only: true)
    get organization_path

    assert_response :success
    assert_select "#shop tr[data-row='shop_admin_only'] [data-status='yes']"
  end

  test "settings overview shows local currency public identifiers but not secret" do
    Current.org.update!(
      features: Current.org.features | [ :local_currency ],
      local_currency_code: "RAD",
      local_currency_identifier: "identifier-to-show",
      local_currency_wallet: "wallet-to-show",
      local_currency_secret: "secret-should-not-appear")
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#local_currency" do |elements|
      card_html = elements.first.to_html
      assert_includes card_html, "RAD"
      assert_includes card_html, "identifier-to-show"
      assert_includes card_html, "wallet-to-show"
      assert_not_includes card_html, "secret-should-not-appear"
      assert_not_includes card_html, "local_currency_secret"
    end
  end

  test "focused edit page only renders selected section inputs" do
    login admins(:super)

    get edit_organization_path(:billing)

    assert_response :success
    assert_includes response.body, "organization_recurring_billing_wday"
    assert_includes response.body, "organization_billing_year_divisions"
    assert_not_includes response.body, "organization_features_input"
    assert_not_includes response.body, "organization_member_form_extra_text_en"
    assert_not_includes response.body, "organization_iban"
  end

  test "billing edit page groups period fields separately" do
    login admins(:super)

    get edit_organization_path(:billing)

    assert_response :success
    billing_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resources.organization.edit_model", locale: admins(:super).language))
    }
    period_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resources.organization.period", locale: admins(:super).language))
    }

    assert billing_fieldset
    assert period_fieldset
    assert_includes billing_fieldset.to_html, "organization_recurring_billing_wday"
    assert_select "#organization_currency_code[disabled]"
    assert_not_includes billing_fieldset.to_html, "organization_fiscal_year_start_month"
    assert_includes period_fieldset.to_html, "organization_fiscal_year_start_month"
    assert_includes period_fieldset.to_html, "organization_billing_starts_after_first_delivery"
    assert_includes period_fieldset.to_html, "organization_billing_ends_on_last_delivery_fy_month"
  end

  test "invoice edit page groups creditor address fields separately" do
    login admins(:super)

    get edit_organization_path(:invoice)

    assert_response :success
    invoice_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.invoice", locale: admins(:super).language))
    }
    address_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("attributes.address", locale: admins(:super).language))
    }

    assert invoice_fieldset
    assert address_fieldset
    assert_includes invoice_fieldset.to_html, "organization_iban"
    assert_includes invoice_fieldset.to_html, "organization_invoice_info_en"
    assert_includes invoice_fieldset.to_html, "organization_invoice_logos"
    assert_not_includes invoice_fieldset.to_html, "organization_creditor_street"
    assert_includes address_fieldset.to_html, "organization_creditor_name"
    assert_includes address_fieldset.to_html, "organization_creditor_street"
    assert_includes address_fieldset.to_html, "organization_creditor_zip"
    assert_includes address_fieldset.to_html, "organization_creditor_city"
  end

  test "general edit page groups contact fields separately" do
    login admins(:super)

    get edit_organization_path(:general)

    assert_response :success
    settings_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resources.organization.edit_model", locale: admins(:super).language))
    }
    contact_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("attributes.contact", locale: admins(:super).language))
    }

    assert settings_fieldset
    assert contact_fieldset
    assert_includes settings_fieldset.to_html, "organization_name"
    assert_includes settings_fieldset.to_html, "organization_url"
    assert_not_includes settings_fieldset.to_html, "organization_email"
    assert_includes contact_fieldset.to_html, "organization_email"
    assert_includes contact_fieldset.to_html, "organization_phone"
    assert_includes contact_fieldset.to_html, "organization_social_network_urls"
  end

  test "registration edit page groups member-facing settings separately" do
    locale = admins(:super).language
    login admins(:super)

    get edit_organization_path(:registration)

    assert_response :success
    registration_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.registration", locale: locale))
    }
    content_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.to_html.include?("organization_member_form_extra_text_#{locale}")
    }
    member_form_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("members.members.form_modes.membership.title", locale: locale))
    }
    more_info_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("members.members.new.more_info", locale: locale))
    }
    documents_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.documents_to_validate", locale: locale))
    }

    assert registration_fieldset
    assert content_fieldset
    assert member_form_fieldset
    assert more_info_fieldset
    assert documents_fieldset
    assert_not_includes registration_fieldset.to_html, "organization_member_form_mode"
    assert_includes registration_fieldset.to_html, "organization_member_form_subtitle_#{locale}"
    assert_not_includes registration_fieldset.to_html, "organization_member_form_extra_text_#{locale}"
    assert_includes content_fieldset.to_html, "organization_member_form_extra_text_#{locale}"
    assert_includes content_fieldset.to_html, "organization_member_form_complements_text_#{locale}"
    assert_not_includes content_fieldset.to_html, "organization_basket_sizes_member_order_mode"
    assert_includes member_form_fieldset.to_html, "organization_basket_sizes_member_order_mode"
    assert_includes member_form_fieldset.to_html, "organization_allow_alternative_depots"
    assert_not_includes member_form_fieldset.to_html, "organization_member_profession_form_mode"
    assert_includes more_info_fieldset.to_html, "organization_member_profession_form_mode"
    assert_includes more_info_fieldset.to_html, "organization_member_come_from_form_mode"
    assert_includes documents_fieldset.to_html, "organization_charter_url_#{locale}"
  end

  test "absence edit page names the billing fieldset explicitly" do
    locale = admins(:super).language
    login admins(:super)

    get edit_organization_path(:absence)

    assert_response :success
    billing_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.billing", locale: locale))
    }
    member_account_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.member_account", locale: locale))
    }
    basket_shifts_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.absence_basket_shifts", locale: locale))
    }
    included_fieldset = css_select("fieldset.inputs").find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.absence_included", locale: locale))
    }

    assert billing_fieldset
    assert member_account_fieldset
    assert basket_shifts_fieldset
    assert included_fieldset
    assert_includes billing_fieldset.to_html, "organization_absences_billed"
    assert_includes member_account_fieldset.to_html, "organization_absence_extra_text_#{locale}"
    assert_includes member_account_fieldset.to_html, "organization_absence_notice_period_in_days"
    assert_includes basket_shifts_fieldset.to_html, "organization_basket_shifts_annually"
    assert_includes included_fieldset.to_html, "organization_absences_included_mode"
  end

  test "activity settings overview summarizes registration form choice" do
    locale = admins(:super).language
    org(features: Current.org.features | [ "activity" ])
    login admins(:super)

    Current.org.update!(
      activity_availability_limit_in_days: 0,
      activity_participation_deletion_deadline_in_days: nil,
      activity_participations_form_min: nil,
      activity_participations_form_max: nil,
      activity_participations_form_step: 2)
    get organization_path

    assert_response :success
    assert_select "#activity", text: /#{Regexp.escape(I18n.t("active_admin.resource.form.registration_form_choice", locale: locale))}/
    assert_select "#activity [data-status='disabled']",
      text: I18n.t("active_admin.resource.form.registration_form_choice_default", locale: locale)
    assert_select "#activity tr[data-row='activity_availability_limit_in_days']",
      text: /#{I18n.t("active_admin.resource.show.none", locale: locale)}/
    assert_select "#activity tr[data-row='activity_participation_deletion_deadline_in_days']",
      text: /#{I18n.t("active_admin.resource.show.none", locale: locale)}/
    assert_select "#activity tr[data-row='activity_participations_demanded_logic']", false

    Current.org.update!(activity_participations_form_min: 2, activity_participations_form_max: nil)
    get organization_path

    assert_response :success
    assert_select "#activity",
      text: /#{Regexp.escape(I18n.t("active_admin.resource.form.registration_form_choice_min", min: 2, step: 2, locale: locale))}/

    Current.org.update!(activity_participations_form_min: nil, activity_participations_form_max: 8)
    get organization_path

    assert_response :success
    assert_select "#activity",
      text: /#{Regexp.escape(I18n.t("active_admin.resource.form.registration_form_choice_max", max: 8, step: 2, locale: locale))}/

    Current.org.update!(activity_participations_form_min: 2, activity_participations_form_max: 8)
    get organization_path

    assert_response :success
    assert_select "#activity",
      text: /#{Regexp.escape(I18n.t("active_admin.resource.form.registration_form_choice_between", min: 2, max: 8, step: 2, locale: locale))}/
  end

  test "basket price extra overview shows titles and raw extra values" do
    locale = admins(:super).language
    title = "Solidarity contribution"
    public_title = "Solidarity choice"
    expected_extras = %w[ 0 1 2 3 ].to_sentence(locale: locale)
    org(features: Current.org.features | [ "basket_price_extra" ])
    Current.org.update!(
      "basket_price_extra_title_#{locale}" => title,
      "basket_price_extra_public_title_#{locale}" => public_title,
      basket_price_extras: "0, 1, 2, 3",
      basket_price_extra_dynamic_pricing: "{{ extra | times: 2 }}")
    login admins(:super)

    get organization_path

    assert_response :success
    assert_select "#basket_price_extra tr[data-row='basket_price_extra_title']", text: /#{Regexp.escape(title)}/
    assert_select "#basket_price_extra tr[data-row='basket_price_extra_title'] [data-status='yes']", false
    assert_select "#basket_price_extra tr[data-row='basket_price_extra_public_title']", text: /#{Regexp.escape(public_title)}/
    assert_select "#basket_price_extra tr[data-row='basket_price_extra_public_title'] [data-status='yes']", false
    assert_select "#basket_price_extra tr[data-row='basket_price_extra_dynamic_pricing'] [data-status='yes']"
    assert_select "#basket_price_extra", text: /\{\{ extra \| times: 2 \}\}/, count: 0

    extras_row = css_select("#basket_price_extra tr[data-row='basket_price_extras']").first
    assert_includes extras_row.text, expected_extras
    assert_not_includes extras_row.text, Current.org.currency_code
    assert_not_includes extras_row.text, ".0"

    Current.org.update!("basket_price_extra_public_title_#{locale}" => nil)
    get organization_path

    assert_response :success
    assert_select "#basket_price_extra tr[data-row='basket_price_extra_public_title'] [data-status='unconfigured']",
      text: I18n.t("active_admin.resources.organization.not_configured", locale: locale)
  end

  test "activity edit page groups member account before registration form" do
    locale = admins(:super).language
    org(features: Current.org.features | [ "activity" ])
    login admins(:super)

    get edit_organization_path(:activity)

    assert_response :success
    fieldsets = css_select("fieldset.inputs")
    settings_fieldset = fieldsets.find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resources.organization.edit_model", locale: locale))
    }
    member_account_fieldset = fieldsets.find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.member_account", locale: locale))
    }
    registration_form_fieldset = fieldsets.find { |fieldset|
      fieldset.css("legend").text.include?(I18n.t("active_admin.resource.form.registration_form", locale: locale))
    }
    logic_fieldset = fieldsets.find { |fieldset|
      fieldset.to_html.include?("organization_activity_participations_demanded_logic")
    }

    assert settings_fieldset
    assert member_account_fieldset
    assert registration_form_fieldset
    assert logic_fieldset
    assert_operator fieldsets.index(settings_fieldset), :<, fieldsets.index(member_account_fieldset)
    assert_operator fieldsets.index(member_account_fieldset), :<, fieldsets.index(registration_form_fieldset)
    assert_operator fieldsets.index(registration_form_fieldset), :<, fieldsets.index(logic_fieldset)
    assert_includes member_account_fieldset.to_html, "organization_activity_availability_limit_in_days"
    assert_includes member_account_fieldset.to_html, "organization_activity_participation_deletion_deadline_in_days"
    assert_not_includes member_account_fieldset.to_html, "organization_activity_participations_form_min"
    assert_includes registration_form_fieldset.to_html, "organization_activity_participations_form_min"
    assert_includes registration_form_fieldset.to_html, "organization_activity_participations_form_max"
    assert_includes registration_form_fieldset.to_html, "organization_activity_participations_form_step"
    assert_includes registration_form_fieldset.to_html, "organization_member_form_activity_participations_text_#{locale}"
    assert_includes registration_form_fieldset.to_html, "organization_activity_participations_form_detail_#{locale}"
  end

  test "focused edit page uses settings breadcrumb and section title" do
    login admins(:super)

    get edit_organization_path(:billing)

    assert_response :success
    assert_select "nav[aria-label='Breadcrumb'] a[href='#{organization_path}']",
      text: I18n.t("active_admin.resources.organization.edit_model", locale: admins(:super).language)
    assert_select "h2[aria-label='Page Title']",
      text: I18n.t("active_admin.resource.form.billing", locale: admins(:super).language)
    assert_select "fieldset.inputs legend",
      text: /#{I18n.t("active_admin.resources.organization.edit_model", locale: admins(:super).language)}/
    assert_select "fieldset.inputs legend",
      text: /#{I18n.t("active_admin.resources.organization.period", locale: admins(:super).language)}/
    assert_select ".panel-actions a[href='#{handbook_page_path("billing")}']"
  end

  test "remaining focused edit pages render after first-pass grouping" do
    dutch_org
    login admins(:super)

    %w[
      registration member_information membership_updates membership_renewal delivery_sheets mailer
      annual_fee shares vat sepa absence activity basket_content basket_price_extra
      bidding_round contact_sharing waiting_list local_currency new_member_fee shop
    ].each do |section|
      get edit_organization_path(section)

      assert_response :success, "#{section} settings should render"
    end
  end

  test "contact sharing overview shows sharing members count" do
    locale = admins(:super).language
    org(features: Current.org.features | [ "contact_sharing" ])
    Member.update_all(contact_sharing: false)
    members(:john).update!(contact_sharing: true)
    members(:anna).update!(contact_sharing: true)
    login admins(:super)

    get organization_path

    assert_response :success
    assert_includes response.body, edit_organization_path(:contact_sharing)
    assert_select "#contact_sharing", text: /#{Regexp.escape(I18n.t("features.contact_sharing_hint", locale: locale))}/
    assert_select "#contact_sharing tr[data-row='members_sharing_contact']", text: /2/
  end

  test "feature edit pages render an activation checkbox" do
    login admins(:super)

    get edit_organization_path(:contact_sharing)

    assert_response :success
    assert_select "fieldset.inputs legend", text: /#{I18n.t("active_admin.resources.organization.activation", locale: admins(:super).language)}/
    assert_select "fieldset.inputs", count: 1
    assert_select "fieldset.inputs legend", text: /#{I18n.t("active_admin.resources.organization.edit_model", locale: admins(:super).language)}/, count: 0
    assert_select "input[name='organization[features][]'][value='contact_sharing']"
  end

  test "converted optional setting edit pages render an activation checkbox" do
    dutch_org(features: [])
    login admins(:super)

    %w[annual_fee member_information shares vat sepa].each do |section|
      get edit_organization_path(section)

      assert_response :success
      assert_select "form#edit_organization[data-turbo='false']"
      assert_select "input[name='organization[features][]'][value='#{section}']"
    end
  end

  test "disabled feature configure links render activation checked by default" do
    org(features: [])
    login admins(:super)

    get edit_organization_path(:contact_sharing, activate: true)

    assert_response :success
    assert_select "input[name='organization[features][]'][value='contact_sharing'][checked='checked']"
  end

  test "disabled setting-less feature card links to focused edit form" do
    org(features: [])
    login admins(:super)

    get organization_path

    assert_response :success
    assert_includes response.body, edit_organization_path(:contact_sharing, activate: true)
  end

  test "saving a setting-less inactive optional feature activates it" do
    org(features: [])
    login admins(:super)

    patch organization_path, params: {
      section: "contact_sharing",
      organization: { features: [ "contact_sharing" ] }
    }

    assert_redirected_to organization_path(anchor: "contact_sharing")
    assert Current.org.reload.feature?(:contact_sharing)
  end

  test "saving a setting-less active optional feature deactivates it" do
    org(features: [ "contact_sharing" ])
    login admins(:super)

    patch organization_path, params: {
      section: "contact_sharing",
      organization: { features: [ "" ] }
    }

    assert_redirected_to organization_path(anchor: "contact_sharing")
    assert_not Current.org.reload.feature?(:contact_sharing)
  end

  test "unknown edit sections redirect to settings overview" do
    login admins(:super)

    get edit_organization_path(:unknown)

    assert_redirected_to organization_path
  end

  test "saving an inactive optional feature activates it" do
    org(features: [])
    login admins(:super)

    patch organization_path, params: {
      section: "bidding_round",
      organization: {
        features: [ "bidding_round" ],
        bidding_round_basket_size_price_min_percentage: 10,
        bidding_round_basket_size_price_max_percentage: 120,
        open_bidding_round_reminder_sent_after_in_days: 7
      }
    }

    assert_redirected_to organization_path(anchor: "bidding_round")
    assert Current.org.reload.feature?(:bidding_round)
  end

  test "validation failure in a focused section re-renders the selected section" do
    org(features: [])
    login admins(:super)

    patch organization_path, params: {
      section: "local_currency",
      organization: {
        features: [ "local_currency" ],
        local_currency_code: "",
        local_currency_identifier: "",
        local_currency_wallet: "",
        local_currency_secret: ""
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "organization_local_currency_code"
    assert_includes response.body,
      ERB::Util.html_escape(I18n.t("errors.messages.blank", locale: admins(:super).language))
    assert_not_includes response.body, "organization_member_form_extra_text_en"
    assert_not Current.org.reload.feature?(:local_currency)
  end

  test "activating converted optional setting with missing config re-renders focused section" do
    org(features: (Current.org.features - [ :annual_fee ]).map(&:to_s), annual_fee: nil)
    login admins(:super)

    patch organization_path, params: {
      section: "annual_fee",
      organization: {
        features: [ "annual_fee" ],
        annual_fee: ""
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "organization_annual_fee"
    assert_includes response.body,
      ERB::Util.html_escape(I18n.t("errors.messages.blank", locale: admins(:super).language))
    assert_not_includes response.body, "organization_member_form_extra_text_en"
    assert_not Current.org.reload.feature?(:annual_fee)
  end
end
