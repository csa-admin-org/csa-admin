module Billing
  class MembershipACPShare
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
      attrs[:acp_shares_number] = missing_acp_shares_number
      member.invoices.create!(attrs)
    end

    def billable?
      membership && missing_acp_shares_number.positive?
    end

    def missing_acp_shares_number
      @missing_acp_shares_number ||=
        membership.basket_size.acp_shares_number - member.acp_shares_number
    end

    def membership
      @membership ||= member.memberships.ongoing.first
    end
  end
end
