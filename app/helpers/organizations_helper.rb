# frozen_string_literal: true

module OrganizationsHelper
  def all_features
    features = Organization.features
    unless current_admin.ultra?
      features -= Organization.restricted_features
    end
    features
  end

  def feature?(feature)
    return if feature.to_sym.in?(Organization.restricted_features) && !current_admin.ultra?

    Current.org.feature?(feature)
  end

  def fiscal_year_months_range
    Current.org.current_fiscal_year
      .range.minmax
      .map { |d| l(d, format: "%B") }
      .join(" – ")
  end

  def link_to_org_website(options = {})
    link_to Current.org.url.sub(/https?:\/\//, ""), Current.org.url, options
  end

  def org_logo_url
    if Current.org.logo.attached?
      Rails.application.routes.url_helpers.logo_url(Tenant.current, host: ENV["ASSET_HOST"])
    else
      image_url("logo.png", host: Current.org.admin_url)
    end
  end

  def membership_renewed_attributes_collection
    col = [
      membership_renewed_attribute_item(:baskets_annual_price_change),
      membership_renewed_attribute_item(:basket_complements_annual_price_change)
    ]
    if feature?("absence")
      col << membership_renewed_attribute_item(:absences_included_annually)
    end
    if feature?("activity")
      label = "#{activities_human_name} (#{t('active_admin.resource.form.full_year')})"
      col << membership_renewed_attribute_item(:activity_participations, label: label)
    end
    col
  end

  def org_languages_collection
    Organization.languages.map { |l| [ t("languages.#{l}"), l ] }.sort_by(&:first)
  end

  def billing_year_divisions_collection
    Organization.billing_year_divisions.map { |i|
      [
        I18n.t("billing.year_division.x#{i}"),
        i
      ]
    }
  end

  def sepa_creditor_identifier_placeholder
    case Current.org.country_code
    when "DE" then "DE98ZZZ09999999999"
    when "NL" then "NL00ZZZ123456780000"
    end
  end

  private

  def membership_renewed_attribute_item(attribute, label: nil)
    label ||= Membership.human_attribute_name(attribute)
    hint = t("formtastic.hints.membership_renewed_attributes.#{attribute}", default: nil)

    label_content = if hint
      content_tag(:span) do
        content_tag(:span, label) +
        content_tag(:span, hint, class: "block text-gray-500 dark:text-gray-400 text-sm font-normal")
      end
    else
      label
    end

    [ label_content, attribute.to_s ]
  end
end
