class AddHalfdayI18nScopeToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :halfday_i18n_scope, :string, null: false, default: 'halfday_work'
  end
end
