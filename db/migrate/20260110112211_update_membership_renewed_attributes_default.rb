# frozen_string_literal: true

class UpdateMembershipRenewedAttributesDefault < ActiveRecord::Migration[8.1]
  def up
    change_column_default :organizations, :membership_renewed_attributes, %w[
      baskets_annual_price_change
      basket_complements_annual_price_change
      activity_participations
      absences_included_annually
    ]
  end

  def down
    change_column_default :organizations, :membership_renewed_attributes, %w[
      baskets_annual_price_change
      basket_complements_annual_price_change
      activity_participations_demanded_annually
      activity_participations_annual_price_change
      absences_included_annually
    ]
  end
end
