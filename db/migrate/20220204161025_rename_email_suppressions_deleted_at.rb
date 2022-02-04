class RenameEmailSuppressionsDeletedAt < ActiveRecord::Migration[6.1]
  def change
    rename_column :email_suppressions, :deleted_at, :unsuppressed_at
  end
end
