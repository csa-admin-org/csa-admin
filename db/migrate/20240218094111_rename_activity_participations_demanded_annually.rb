class RenameActivityParticipationsDemandedAnnually < ActiveRecord::Migration[7.1]
  def change
    rename_column :basket_sizes, :activity_participations_demanded_annualy, :activity_participations_demanded_annually
    rename_column :basket_complements, :activity_participations_demanded_annualy, :activity_participations_demanded_annually
    rename_column :memberships, :activity_participations_demanded_annualy, :activity_participations_demanded_annually

    change_column_default :acps, :membership_renewed_attributes,
      from: %w[
        baskets_annual_price_change
        basket_complements_annual_price_change
        activity_participations_demanded_annualy
        activity_participations_annual_price_change
        absences_included_annually
      ],
      to: %w[
        baskets_annual_price_change
        basket_complements_annual_price_change
        activity_participations_demanded_annually
        activity_participations_annual_price_change
        absences_included_annually
      ]

    up_only do
      if Tenant.outside?
        ACP.find_each do |acp|
          attrs = acp.membership_renewed_attributes
          if i = array.index("activity_participations_demanded_annualy")
            array[i] = "activity_participations_demanded_annually"
          end
          acp.update!(membership_renewed_attributes: attrs)
        end
      end
    end
  end
end
