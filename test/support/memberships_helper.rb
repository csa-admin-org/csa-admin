# frozen_string_literal: true

module MembershipsHelper
  def build_membership(attributes = {})
    Membership.new({
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: Date.current.beginning_of_year,
      ended_on: Date.current.end_of_year
    }.merge(attributes))
  end

  def create_membership(attributes = {})
    build_membership(attributes).tap(&:save!)
  end
end
