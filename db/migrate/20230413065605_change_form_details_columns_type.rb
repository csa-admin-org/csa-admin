class ChangeFormDetailsColumnsType < ActiveRecord::Migration[7.0]
  def change
    rename_column :basket_sizes, :form_details, :form_details_old
    add_column :basket_sizes, :form_details, :jsonb, default: {}, null: false
    BasketSize.find_each do |bs|
      if bs.form_details_old.present?
        bs[:form_details] = { 'fr' => bs.form_details_old }
        bs.save!
      end
    end
    remove_column :basket_sizes, :form_details_old

    rename_column :basket_complements, :form_details, :form_details_old
    add_column :basket_complements, :form_details, :jsonb, default: {}, null: false
    BasketComplement.find_each do |bc|
      if bc.form_details_old.present?
        bc[:form_details] = { 'fr' => bc.form_details_old }
        bc.save!
      end
    end
    remove_column :basket_complements, :form_details_old
  end
end
