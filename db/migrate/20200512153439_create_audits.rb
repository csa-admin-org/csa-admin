class CreateAudits < ActiveRecord::Migration[6.0]
  def change
    create_table :audits do |t|
      t.references :session
      t.references :auditable, polymorphic: true

      t.jsonb :audited_changes, default: {}, null: false

      t.timestamps
    end
    add_index :audits, :created_at
  end
end
