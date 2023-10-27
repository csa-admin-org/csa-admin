module Billing
  class MissingActivityParticipationsInvoicerJob < ApplicationJob
    queue_as :low

    def perform(membership)
      missing_count = membership.missing_activity_participations
      return unless missing_count.positive?
      return unless Current.acp.activity_price.positive?

      Invoice.create!(
        send_email: true,
        member: membership.member,
        date: [Date.today, membership.fiscal_year.end_of_year].min,
        entity_type: 'ActivityParticipation',
        paid_missing_activity_participations: missing_count)
    end
  end
end
