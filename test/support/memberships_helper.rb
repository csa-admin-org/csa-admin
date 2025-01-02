# frozen_string_literal: true

module MembershipsHelper
  def create_membership(attributes = {})
    attributes[:member] ||= create_member
    Membership.create!({
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: Date.today.beginning_of_year,
      ended_on: Date.today.end_of_year
    }.merge(attributes))
  end
end
