module Billing
  class Snapshot < ApplicationRecord
    self.table_name = "billing_snapshots"

    TIME_WINDOW = 15.minutes

    def self.end_of_quarter?
      max = Current.fiscal_year.current_quarter_range.max
      range = (max - TIME_WINDOW)..max
      range.cover?(Time.current)
    end

    def self.create_or_update_current_quarter!
      return unless end_of_quarter?

      fy = Current.fiscal_year
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
