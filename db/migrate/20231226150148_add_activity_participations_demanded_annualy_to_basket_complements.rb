class AddActivityParticipationsDemandedAnnualyToBasketComplements < ActiveRecord::Migration[7.1]
  def change
    add_column :basket_complements, :activity_participations_demanded_annualy, :integer, default: 0, null: false
  end
end
