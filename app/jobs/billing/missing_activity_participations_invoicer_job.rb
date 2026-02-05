# frozen_string_literal: true

module Billing
  class MissingActivityParticipationsInvoicerJob < ApplicationJob
    queue_as :low

    def perform(membership)
      return unless Current.org.iban?

      missing_count = membership.activity_participations_missing
      return unless missing_count.positive?
      return unless Current.org.activity_price.positive?

      Invoice.create!(
        send_email: true,
        member: membership.member,
        date: Date.current,
        entity_type: "ActivityParticipation",
        missing_activity_participations_fiscal_year: membership.fiscal_year,
        missing_activity_participations_count: missing_count)

      # Ensure that for Organization that might have changed their first fiscal year month
      # the past membership is still updated correctly
      membership.update_activity_participations_accepted!
    end
  end
end
