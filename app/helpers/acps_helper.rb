module AcpsHelper
  def feature?(feature)
    Current.acp.feature?(feature)
  end

  def fiscal_year_months_range
    Current.acp.current_fiscal_year
      .range.minmax
      .map { |d| l(d, format: "%B") }
      .join(" – ")
  end

  def link_to_acp_website(options = {})
    link_to Current.acp.url.sub(/https?:\/\//, ""), Current.acp.url, options
  end

  def membership_renewed_attributes_collection
    col = [ [
      Membership.human_attribute_name(:baskets_annual_price_change),
      "baskets_annual_price_change"
    ] ]
    if BasketComplement.any?
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
        "#{activities_human_name} (#{t('active_admin.resource.edit.full_year')})",
        "activity_participations_demanded_annually"
      ]
    end
    col
  end
end
