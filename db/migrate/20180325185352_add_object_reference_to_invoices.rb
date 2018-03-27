class AddObjectReferenceToInvoices < ActiveRecord::Migration[5.2]
  def change
    add_reference :invoices, :object, polymorphic: true, index: true

    # Invoice.where.not(memberships_amount: nil).includes(:member).find_each do |i|
    #   if membership_id = i.member.memberships.during_year(i.fiscal_year).pluck(:id).first
    #     i.update_columns(object_id: membership_id, object_type: 'Membership')
    #   end
    # end
  end
end
