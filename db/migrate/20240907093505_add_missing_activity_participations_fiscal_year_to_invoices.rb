# frozen_string_literal: true

class AddMissingActivityParticipationsFiscalYearToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :missing_activity_participations_fiscal_year, :integer
    rename_column :invoices, :paid_missing_activity_participations, :missing_activity_participations_count

    up_only do
      if Tenant.inside?
        org = Organization.find_by(tenant_name: Tenant.current)
        Invoice.where(entity_type: "ActivityParticipation").find_each do |invoice|
          invoice.update_column(
            :missing_activity_participations_fiscal_year,
            org.fiscal_year_for(invoice.date).year)
        end
      end
    end
  end
end
