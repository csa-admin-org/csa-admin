# frozen_string_literal: true

module DeliveryCounts
  extend ActiveSupport::Concern

  def deliveries_counts
    DeliveryCycle.deliveries_counts_for(self)
  end

  def absences_included_counts
    DeliveryCycle.absences_included_counts_for(self)
  end

  def billable_deliveries_counts
    DeliveryCycle.billable_deliveries_counts_for(self)
  end
end
