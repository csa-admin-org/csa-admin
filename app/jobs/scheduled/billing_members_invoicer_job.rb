# frozen_string_literal: true

module Scheduled
  class BillingMembersInvoicerJob < BaseJob
    def perform
      return unless Current.org.recurring_billing_wday == Date.current.wday

      Member.find_each do |member|
        Billing::MemberInvoicerJob.perform_later(member)
      end
    end
  end
end
