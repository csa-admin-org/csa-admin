# frozen_string_literal: true

class AbsencesIncluded
  class MembershipDrop < Liquid::Drop
    include MembershipLiquidIdentifiers

    def initialize(membership)
      @membership = membership
    end

    def full_year_absences_included
      @membership.absences_included_annually.to_f
    end

    def baskets
      @membership.baskets.count.to_f
    end

    def full_year_deliveries
      fy_deliveries_count.to_f
    end

    def depot_id
      @membership.depot_id
    end

    def depot_group_id
      @membership.depot&.group_id
    end

    private

    def fy_deliveries_count
      @membership.delivery_cycle.deliveries_in(@membership.fiscal_year.range).size
    end
  end

  def initialize(membership)
    @membership = membership
    @liquid_template = Liquid::Template.parse(Current.org.absences_included_logic)
  end

  def count
    return 0 unless fy_deliveries_count.positive? && @membership.absences_included_annually.positive?

    [ @liquid_template.render(
      "membership" => MembershipDrop.new(@membership)).to_i, 0 ].max
  end

  private

  def fy_deliveries_count
    @membership.delivery_cycle.deliveries_in(@membership.fiscal_year.range).size
  end
end
