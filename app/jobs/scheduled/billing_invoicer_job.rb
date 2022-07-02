module Scheduled
  class BillingInvoicerJob < BaseJob
    def perform
      return unless Current.acp.recurring_billing_wday == Date.current.wday

      Member.find_each do |member|
        Billing::MemberInvoicerJob.perform_later(member)
      end
    end
  end
end
