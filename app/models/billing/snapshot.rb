module Billing
  class Snapshot < ActiveRecord::Base
    self.table_name = 'billing_snapshots'

    def self.create_or_update_current_quarter!
      fy = Current.acp.current_fiscal_year
      xlsx = XLSX::Billing.new(fy.year)
      if snapshot = find_by(created_at: fy.current_quarter_range)
        snapshot.update!(file: xlsx.file)
        snapshot
      else
        create!(file: xlsx.file)
      end
    end

    has_one_attached :file
  end
end
