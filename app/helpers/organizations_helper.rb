# frozen_string_literal: true

module OrganizationsHelper
  def feature?(feature)
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
      logo_url(Tenant.current, host: ENV["ASSET_HOST"])
    else
      image_path("logo.png")
    end
  end

  def membership_renewed_attributes_collection
    col = [ [
      Membership.human_attribute_name(:baskets_annual_price_change),
      "baskets_annual_price_change"
    ] ]
    if BasketComplement.kept.any?
      col << [
        Membership.human_attribute_name(:basket_complements_annual_price_change),
        "basket_complements_annual_price_change"
      ]
    end
    if feature?("absence")
      col << [
        Membership.human_attribute_name(:absences_included_annually),
        "absences_included_annually"
      ]
    end
    if feature?("activity")
      col <<  [
        "#{t('formtastic.labels.membership.activity_participations_annual_price_change')} (#{activities_human_name})",
        "activity_participations_annual_price_change"
      ]
      col <<  [
        "#{activities_human_name} (#{t('active_admin.resource.form.full_year')})",
        "activity_participations_demanded_annualy"
      ]
    end
    col
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
end
