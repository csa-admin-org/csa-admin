class AddMemberFormModes < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :member_profession_form_mode, :string, null: false, default: 'visible'
    add_column :acps, :member_come_from_form_mode, :string, null: false, default: 'visible'
  end
end
