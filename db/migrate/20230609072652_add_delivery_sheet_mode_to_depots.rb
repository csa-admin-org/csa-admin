class AddDeliverySheetModeToDepots < ActiveRecord::Migration[7.0]
  def change
    add_column :depots, :delivery_sheets_mode, :string, default: 'signature', null: false
    remove_column :depots, :xlsx_worksheet_style
  end
end
