module Billing
  class InvoicerACPShare
    attr_reader :member

    def self.invoice(member, **attrs)
      new(member).invoice(**attrs)
    end

    def initialize(member)
      @member = member
    end

    def invoice(**attrs)
      return unless billable?

      attrs[:date] = Date.current
      attrs[:acp_shares_number] = member.missing_acp_shares_number
      member.invoices.create!(attrs)
    end

    def billable?
      (ongoing_membership || member.support? || member.shop_depot_id?) &&
        member.billable? &&
        member.missing_acp_shares_number.positive?
    end

    def next_date
      return unless Current.acp.recurring_billing?

      today = Date.current
      today + ((Current.acp.recurring_billing_wday - today.wday) % 7).days
    end

    private

    def ongoing_membership
      member.memberships.ongoing.first
    end
  end
end
