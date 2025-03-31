# frozen_string_literal: true

class AddUniqueIndexOnMembersSEPAMandateId < ActiveRecord::Migration[8.1]
  def change
    add_index :members, :sepa_mandate_id, unique: true
  end
end
