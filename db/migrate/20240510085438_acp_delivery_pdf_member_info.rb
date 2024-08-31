# frozen_string_literal: true

class AcpDeliveryPDFMemberInfo < ActiveRecord::Migration[7.1]
  def change
    add_column :acps, :delivery_pdf_member_info, :string, default: "none", null: false

    up_only do
      if Tenant.inside?
        org = Organization.find_by(tenant_name: Tenant.current)
        if org.delivery_pdf_show_phones?
          org.update_column :delivery_pdf_member_info, "phones"
        end
      end
    end
  end
end
