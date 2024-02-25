class ActivityParticipationDemanded
  class MemberDrop < Liquid::Drop
    def initialize(member)
      @member = member
    end

    def salary_basket
      @member.salary_basket?
    end
  end

  class MembershipDrop < Liquid::Drop
    def initialize(membership)
      @membership = membership
    end

    def full_year_deliveries
      [
        deliveries_count(@membership.fiscal_year.range),
        baskets
      ].max
    end

    def full_year_activity_participations
      @membership.activity_participations_demanded_annually.to_f
    end

    def baskets
      @baskets ||= deliveries_count(@membership.period)
    end

    private

    def deliveries_count(range)
      @membership.delivery_cycle.deliveries_in(range).size.to_f
    end
  end

  def initialize(membership)
    @membership = membership
    liquid_logic = Current.acp.activity_participations_demanded_logic
    @liquid_template = Liquid::Template.parse(liquid_logic)
  end

  def count
    @liquid_template.render(
      "member" => MemberDrop.new(@membership.member),
      "membership" => MembershipDrop.new(@membership)).to_i
  end
end
