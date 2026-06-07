# frozen_string_literal: true

module ActiveAdmin::OrganizationSettingsHelper
  def organization_setting_sections
    sections = [
      organization_setting_section_definition(:general, :core, "active_admin.resource.form.general", "sliders-horizontal"),
      organization_setting_section_definition(:mailer, :core, "active_admin.resource.form.mailer", "mail", handbook: "emails"),
      organization_setting_section_definition(:billing, :core, "active_admin.resource.form.billing", "banknotes", handbook: "billing"),
      organization_setting_section_definition(:invoice, :core, "active_admin.resource.form.invoice", "receipt-text", handbook: "billing"),
      organization_setting_section_definition(:registration, :core, "active_admin.resource.form.registration", "form", handbook: "registration"),
      organization_setting_section_definition(:delivery_sheets, :core, "active_admin.resource.form.delivery_sheets", "file-spreadsheet", handbook: "deliveries", handbook_anchor: "delivery-sheets", legacy_anchors: %w[pdf-sheets delivery]),
      organization_setting_section_definition(:membership_updates, :core, "active_admin.resource.form.membership_updates", "calendar-range"),
      organization_setting_section_definition(:membership_renewal, :core, "active_admin.resource.form.membership_renewal", "refresh-cw", handbook: "membership_renewal"),

      organization_setting_section_definition(:annual_fee, :feature, "features.annual_fee", "calendar-sync", handbook: "billing", handbook_anchor: "annual-fee"),
      organization_setting_section_definition(:member_information, :feature, "features.member_information", "newspaper", handbook: "members", handbook_anchor: "information-page"),
      organization_setting_section_definition(:shares, :feature, "features.shares", "receipt-text", handbook: "billing", handbook_anchor: "share-capital"),
      organization_setting_section_definition(:vat, :feature, "features.vat", "receipt-text", handbook: "billing", handbook_anchor: "vat"),
      organization_setting_section_definition(:sepa, :feature, "features.sepa", "banknotes", handbook: "sepa"),

      organization_setting_section_definition(:absence, :feature, Absence.model_name.human, "tent", handbook: "absence"),
      organization_setting_section_definition(:activity, :feature, "features.activity", "handshake", handbook: "activity"),
      organization_setting_section_definition(:basket_content, :feature, BasketContent.model_name.human, "sprout", handbook: "basket_content"),
      organization_setting_section_definition(:basket_price_extra, :feature, "features.basket_price_extra", "receipt-text", handbook: "basket_price_extra"),
      organization_setting_section_definition(:bidding_round, :feature, BiddingRound.model_name.human, "scale", handbook: "bidding_round"),
      organization_setting_section_definition(:contact_sharing, :feature, "features.contact_sharing", "contact-round", handbook: "contact_sharing"),
      organization_setting_section_definition(:local_currency, :feature, "features.local_currency", "banknote", handbook: "local_currency"),
      organization_setting_section_definition(:new_member_fee, :feature, "features.new_member_fee", "plus", handbook: "new_member_fee"),
      organization_setting_section_definition(:shop, :feature, "shop.title", "shopping-basket", handbook: "shop")
    ]

    sections.select { |section| organization_setting_section_visible?(section) }
  end

  def organization_setting_section(key)
    if key.is_a?(Hash)
      key
    else
      organization_setting_sections.find { |section| section[:key] == key.to_s }
    end
  end

  def organization_setting_section_keys
    organization_setting_sections.map { |section| section[:key] }
  end

  def organization_enabled_setting_sections(org = Current.org)
    sections = organization_setting_sections.select { |section|
      organization_setting_section_available?(section, org) &&
        (section[:kind] == :core || organization_setting_section_enabled?(section, org))
    }

    core_sections, optional_sections = sections.partition { |section| section[:kind] == :core }
    core_sections + optional_sections.sort_by { |section| organization_setting_section_sort_title(section, org) }
  end

  def organization_disabled_setting_sections(org = Current.org)
    organization_setting_sections.select { |section|
      organization_setting_section_available?(section, org) &&
        section[:kind] != :core &&
        !organization_setting_section_enabled?(section, org)
    }.sort_by { |section| organization_setting_section_sort_title(section, org) }
  end

  def organization_setting_section_title(section, org = Current.org)
    section = organization_setting_section(section)
    return activities_human_name if section[:key] == "activity" && organization_setting_section_enabled?(section, org)

    title = section[:title]
    title.to_s.include?(".") ? t(title) : title
  end

  def organization_setting_section_enabled?(section, org = Current.org)
    section = organization_setting_section(section)
    section[:kind] == :core || org.feature?(section[:key])
  end

  def organization_setting_section_available?(section, org = Current.org)
    section = organization_setting_section(section)
    section[:key] != "sepa" || org.sepa_country?
  end

  def organization_setting_section_feature?(section)
    organization_setting_section(section)[:kind] == :feature
  end

  def organization_setting_section_editable?(_section)
    true
  end

  def organization_setting_section_activation?(section, org = Current.org)
    section = organization_setting_section(section)
    organization_setting_section_available?(section, org) &&
      section[:kind] != :core &&
      !organization_setting_section_enabled?(section, org)
  end

  def organization_setting_section_actions(section, org = Current.org)
    actions = []
    actions << organization_setting_section_website_action(org) if section[:key] == "general" && org.url.present?
    actions << organization_setting_section_registration_action if section[:key] == "registration"
    actions << organization_setting_section_handbook_action(section) if section[:handbook]
    actions << organization_setting_section_edit_action(section, org) if authorized?(:update, Organization) && organization_setting_section_editable?(section)

    safe_join(actions, " ")
  end

  def organization_disabled_setting_section_actions(section)
    actions = []
    actions << organization_setting_section_handbook_action(section) if section[:handbook]
    safe_join(actions, " ")
  end

  def organization_disabled_setting_section_primary_action(section)
    link_to edit_organization_path(section[:key], activate: true), class: "btn btn-sm" do
      safe_join([
        icon("square-pen", class: "size-4"),
        I18n.t("active_admin.resources.organization.configure")
      ], " ")
    end
  end

  def organization_disabled_setting_section_hint(section)
    I18n.t("features.#{section[:key]}_hint", default: "")
  end

  def organization_settings_status_tag(value, status: nil)
    status, label = if value == true || value == false
      key = value ? "yes" : "no"
      [ key, I18n.t("active_admin.status_tag.#{key}") ]
    else
      [ (status || value).to_s.parameterize(separator: "_"), value ]
    end

    content_tag(:span, label, class: "status-tag", data: { status: status })
  end

  def organization_settings_missing_status_tag
    organization_settings_status_tag(
      I18n.t("active_admin.resources.organization.not_configured"),
      status: :unconfigured)
  end

  def organization_settings_presence_status_tag(value)
    value.present? ? organization_settings_status_tag(true) : organization_settings_missing_status_tag
  end

  def organization_settings_currency_value(amount)
    amount.present? ? cur(amount) : organization_settings_missing_status_tag
  end

  def organization_settings_percentage_value(amount)
    amount.present? ? number_to_percentage(amount, precision: 2) : organization_settings_missing_status_tag
  end

  def organization_settings_percentage_values(amounts)
    values = Array(amounts).compact_blank
    return organization_settings_missing_status_tag if values.none?

    values.map { |amount| number_to_percentage(amount, precision: 0) }.to_sentence
  end

  def organization_settings_currency_values(amounts)
    values = Array(amounts).compact_blank
    return organization_settings_missing_status_tag if values.none?

    values.map { |amount| cur(amount) }.to_sentence
  end

  def organization_settings_number_values(amounts)
    values = Array(amounts).compact_blank
    return organization_settings_missing_status_tag if values.none?

    numbers = values.map { |value| BigDecimal(value.to_s) }
    numbers.map { |number| organization_settings_number_value(number) }.to_sentence
  end

  def organization_settings_number_value(number)
    if number.frac.zero?
      number.to_i.to_s
    else
      number.to_s("F").sub(/\.?0+\z/, "")
    end
  end

  def organization_settings_weight_value(amount)
    amount.present? ? "#{amount} kg" : organization_settings_missing_status_tag
  end

  def organization_settings_range_value(min, max)
    return "#{min} – #{max}" if min.present? && max.present?
    return "≥ #{min}" if min.present?
    return "≤ #{max}" if max.present?

    organization_settings_missing_status_tag
  end

  def organization_settings_activity_participations_form_choice(org)
    min = org.activity_participations_form_min
    max = org.activity_participations_form_max
    step = org.activity_participations_form_step

    if min.present? && max.present?
      t("active_admin.resource.form.registration_form_choice_between", min: min, max: max, step: step)
    elsif min.present?
      t("active_admin.resource.form.registration_form_choice_min", min: min, step: step)
    elsif max.present?
      t("active_admin.resource.form.registration_form_choice_max", max: max, step: step)
    else
      organization_settings_status_tag(
        t("active_admin.resource.form.registration_form_choice_default"),
        status: :disabled)
    end
  end

  def organization_settings_list_value(values)
    values = Array(values).compact_blank
    return organization_settings_missing_status_tag if values.none?

    content_tag(:ul, class: "list-disc list-outside pl-5 text-left space-y-1") do
      safe_join(values.map { |value| content_tag(:li, value) })
    end
  end

  def organization_settings_text_value(value, class_name: "text-left text-sm")
    return organization_settings_missing_status_tag if value.blank?

    classes = [ class_name, "leading-relaxed text-gray-600 dark:text-gray-300" ].join(" ")
    simple_format(value, { class: classes })
  end

  def organization_settings_form_mode_status(mode)
    return organization_settings_missing_status_tag if mode.blank?

    organization_settings_status_tag(t("form_modes.#{mode}"), status: mode)
  end

  def organization_settings_documents_status(org)
    links = %i[
      charter
      statutes
      terms_of_service
      privacy_policy
    ].filter_map { |document|
      url = organization_settings_document_url(org, document)
      next if url.blank?

      link_to(
        t("members.members.new.documents.#{document}"),
        url,
        target: "_blank",
        rel: "noopener")
    }

    links.any? ? links.to_sentence.html_safe : organization_settings_missing_status_tag
  end

  def organization_settings_document_url(org, document)
    org.public_send("#{document}_url").presence ||
      org.public_send("#{document}_urls").values.compact_blank.first
  end

  def organization_settings_translated_attribute_status(org, column)
    organization_settings_status_tag(organization_settings_translated_attribute_present?(org, column))
  end

  def organization_settings_translated_attribute_present?(org, column)
    org.public_send(column).values.any?(&:present?)
  end

  def organization_settings_shop_opening(org)
    days = org.shop_delivery_open_delay_in_days.to_i
    time = (org.shop_delivery_open_last_day_end_time || Tod::TimeOfDay.parse("23:59:59")).strftime("%H:%M")

    t("active_admin.resource.form.shop_opening", count: days, time: time)
  end

  def organization_settings_billing_period(org)
    fiscal_year = organization_settings_billing_period_fiscal_year(org)
    deliveries = Delivery.during_year(fiscal_year.year)
    first_date = organization_settings_billing_period_first_date(org, fiscal_year, deliveries)
    last_date = organization_settings_billing_period_last_date(org, fiscal_year, deliveries)

    [ first_date, last_date ].map { |date| l(date, format: "%B").capitalize }.join(" – ")
  end

  def organization_settings_billing_period_fiscal_year(org)
    year = Delivery.any_next_year? ? Current.fy_year + 1 : Current.fy_year
    org.fiscal_year_for(year)
  end

  def organization_settings_billing_period_first_date(org, fiscal_year, deliveries)
    if org.billing_starts_after_first_delivery? && deliveries.exists?
      deliveries.first.date
    else
      fiscal_year.range.min
    end
  end

  def organization_settings_billing_period_last_date(org, fiscal_year, deliveries)
    if org.billing_ends_on_last_delivery_fy_month? && deliveries.exists?
      deliveries.last.date
    else
      fiscal_year.range.max
    end
  end

  def organization_settings_creditor_address(org)
    lines = [
      org.creditor_name,
      org.creditor_street,
      [ org.creditor_zip, org.creditor_city ].compact_blank.join(" ")
    ].compact_blank

    lines.any? ? safe_join(lines, tag.br) : organization_settings_empty_value
  end

  def organization_settings_logo(org)
    return organization_settings_empty_value unless org.logo.persisted?

    content_tag(:ul, class: "flex flex-wrap justify-end gap-2") do
      image_tag org.logo.variant(resize_to_limit: [ 92, 92 ]), class: "logo max-h-9 max-w-16 object-contain"
    end
  end

  def organization_settings_invoice_logos(org)
    logos = org.invoice_logos.select(&:persisted?)
    return organization_settings_empty_value if logos.none?

    content_tag(:ul, class: "flex flex-wrap justify-end gap-2") do
      safe_join(logos.map { |logo|
        content_tag(:li) do
          image_tag logo.variant(resize_to_limit: [ 92, 92 ]), class: "max-h-9 max-w-16 object-contain"
        end
      })
    end
  end

  def organization_settings_empty_value
    content_tag(:span, t("active_admin.empty"), class: "attributes-table-empty-value")
  end

  def organization_settings_social_networks_label
    Organization.human_attribute_name(:social_network_urls).sub(/\s+\([^)]*\)\z/, "")
  end

  def organization_settings_social_network_links(org)
    return organization_settings_missing_status_tag if org.social_networks.none?

    content_tag(:ul, class: "flex flex-wrap justify-end gap-3") do
      safe_join(org.social_networks.map { |network|
        content_tag(:li) do
          link_to network.url,
            title: network.icon.to_s.titleize,
            target: "_blank",
            rel: "noopener",
            class: "flex items-center fill-gray-400 hover:fill-green-500 dark:fill-gray-500 dark:hover:fill-green-500" do
            simpleicons network.icon, class: "size-5"
          end
        end
      })
    end
  end

  private

  def organization_setting_section_definition(key, kind, title, icon, handbook: nil, handbook_anchor: nil, legacy_anchors: [])
    {
      key: key.to_s,
      kind: kind,
      title: title,
      icon: icon,
      handbook: handbook,
      handbook_anchor: handbook_anchor,
      legacy_anchors: legacy_anchors
    }
  end

  def organization_setting_section_visible?(section)
    return true unless section[:kind] == :feature
    return true if current_admin&.ultra?

    Organization.restricted_features.exclude?(section[:key].to_sym)
  end

  def organization_setting_section_sort_title(section, org = Current.org)
    I18n.transliterate(organization_setting_section_title(section, org).downcase)
  end

  def organization_setting_section_website_action(org)
    link_to(
      org.url,
      title: Organization.human_attribute_name(:url),
      target: "_blank",
      rel: "noopener") do
      icon "globe", class: "size-5"
    end
  end

  def organization_setting_section_registration_action
    link_to(
      new_members_member_url(subdomain: Current.org.members_subdomain),
      title: t("active_admin.resource.form.registration_form"),
      target: "_blank",
      rel: "noopener") do
      icon "globe", class: "size-5"
    end
  end

  def organization_setting_section_handbook_action(section)
    link_to(
      handbook_page_path(section[:handbook], anchor: section[:handbook_anchor]),
      title: I18n.t("active_admin.site_footer.handbook")) do
      icon "book-open", class: "size-5"
    end
  end

  def organization_setting_section_edit_action(section, org)
    options = organization_setting_section_activation?(section, org) ? { activate: true } : {}
    link_to(
      edit_organization_path(section[:key], options),
      title: I18n.t("active_admin.resources.organization.edit_section")) do
      icon "square-pen", class: "size-5"
    end
  end
end
