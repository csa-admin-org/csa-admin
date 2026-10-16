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

  def assign_depot_without_renewal_year_deliveries!(membership, extra_cycles: [])
    year = membership.fy_year
    empty = create_delivery_cycle(name: "Empty Cycle", wdays: [ 1 ])
    empty.update_column(:deliveries_counts, { year.to_s => 10, (year + 1).to_s => 0 })
    depot = Depot.create!(
      name: "Empty Depot",
      language: "en",
      price: 0,
      delivery_cycles: [ empty, *extra_cycles ])
    membership.update!(depot: depot, delivery_cycle: empty)
    membership
  end

  def missing_depot_deliveries_message(membership)
    I18n.t("membership_renewal.missing_depot_deliveries",
      year: Current.org.fiscal_year_for(membership.fy_year + 1),
      depot: membership.depot.public_name)
  end
end
