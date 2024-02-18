class AddAbsencesIncluded < ActiveRecord::Migration[7.1]
  def change
    add_column :delivery_cycles, :absences_included_annually, :integer, default: 0, null: false

    add_column :memberships, :absences_included_annually, :integer, default: 0, null: false
    add_column :memberships, :absences_included, :integer, default: 0, null: false

    change_column_default :acps, :membership_renewed_attributes,
      from: %w[
        baskets_annual_price_change
        basket_complements_annual_price_change
        activity_participations_demanded_annualy
        activity_participations_annual_price_change
      ],
      to: %w[
        baskets_annual_price_change
        basket_complements_annual_price_change
        activity_participations_demanded_annualy
        activity_participations_annual_price_change
        absences_included_annually
      ]
  end
end
