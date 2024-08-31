# frozen_string_literal: true

module Billing
  class MissingActivityParticipationsInvoicerJob < ApplicationJob
    queue_as :low

    def perform(membership)
      missing_count = membership.activity_participations_missing
      return unless missing_count.positive?
      return unless Current.org.activity_price.positive?

      Invoice.create!(
        send_email: true,
        member: membership.member,
        date: [ Date.today, membership.fiscal_year.end_of_year ].min,
        entity_type: "ActivityParticipation",
        paid_missing_activity_participations: missing_count)
    end
  end
end
