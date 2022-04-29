class AddDepotsContactName < ActiveRecord::Migration[7.0]
  def change
    add_column :depots, :contact_name, :string
    Depot.where.not(responsible_member_id: nil).find_each do |depot|
      depot.update_column(:contact_name, depot.responsible_member&.name)
    end
  end
end
