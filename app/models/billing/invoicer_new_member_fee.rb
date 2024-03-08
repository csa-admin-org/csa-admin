module Billing
  class InvoicerNewMemberFee
    attr_reader :member

    TIME_WINDOW = 3.weeks

    def self.invoice(member, **attrs)
      new(member).invoice(**attrs)
    end

    def initialize(member)
      @member = member
    end

    def invoice(**attrs)
      return unless Current.acp.feature?("new_member_fee")
      return unless billable?

      attrs[:date] = Date.current
      attrs[:entity_type] = "NewMemberFee"
      I18n.with_locale(member.language) do
        attrs[:items_attributes] = {
          "0" => {
            description: Current.acp.new_member_fee_description,
            amount: Current.acp.new_member_fee
          }
        }
      end
      member.invoices.create!(attrs)
    end

    private

    def billable?
      member.active? &&
        member.billable? &&
        member.invoices.new_member_fee_type.none? &&
        member.first_membership&.first_billable_delivery&.date&.in?(recent_window)
    end

    def recent_window
      (TIME_WINDOW.ago.to_date)..Date.today
    end
  end
end
