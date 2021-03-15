module Billing
  class ACPShare
    attr_reader :member

    def self.invoice!(member, **attrs)
      new(member).invoice!(**attrs)
    end

    def initialize(member)
      @member = member
    end

    def invoice!(**attrs)
      return unless billable?

      attrs[:date] = Date.current
      attrs[:acp_shares_number] = member.missing_acp_shares_number
      member.invoices.create!(attrs)
    end

    private

    def billable?
      (ongoing_membership || member.support?) && member.missing_acp_shares_number.positive?
    end

    def ongoing_membership
      member.memberships.ongoing.first
    end
  end
end
