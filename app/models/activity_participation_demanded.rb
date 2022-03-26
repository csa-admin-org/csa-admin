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
      @membership.deliveries_cycle.deliveries_in(@membership.fiscal_year.range).size.to_f
    end

    def full_year_activity_participations
      @membership.activity_participations_demanded_annualy.to_f
    end

    def baskets
      @membership.baskets_count.to_f
    end
  end

  def initialize(membership, liquid_logic)
    @membership = membership
    @liquid_template = Liquid::Template.parse(liquid_logic)
  end

  def count
    @liquid_template.render(
      'member' => MemberDrop.new(@membership.member),
      'membership' => MembershipDrop.new(@membership)).to_i
  end
end
