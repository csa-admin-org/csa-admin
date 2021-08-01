class AddXLSXWorksheetStyleToDepots < ActiveRecord::Migration[6.1]
  def change
    add_column :depots, :xlsx_worksheet_style, :string, null: false, default: 'default'
  end
end
