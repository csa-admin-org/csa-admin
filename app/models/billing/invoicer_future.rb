# frozen_string_literal: true

module Billing
  class InvoicerFuture
    def self.invoice(membership, **attrs)
      new(membership).invoice(**attrs)
    end

    def initialize(membership)
      @membership = membership
      @invoicer = Invoicer.new(membership.member,
        membership: membership,
        period_date: membership.started_on,
        billing_year_division: 1)
    end

    def billable?
      @membership.future? &&
        @membership.billable? &&
        @invoicer.billable?
    end

    def invoice(**attrs)
      return unless billable?

      @invoicer.invoice(**attrs)
    end
  end
end
