# frozen_string_literal: true

class AddMemberFormComplementQuantitiesToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :member_form_complement_quantities, :boolean, default: false, null: false
  end
end

# Tenant.switch_each do |tenant|
#   if BasketComplement.visible.any?
#     Current.org.update!(member_form_complement_quantities: true)
#   end
# end
