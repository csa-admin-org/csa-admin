# frozen_string_literal: true

require "test_helper"

class ActivityParticipationDemandedTest < ActiveSupport::TestCase
  def demanded_for(membership)
    ActivityParticipationDemanded.new(membership).count
  end

  test "salary basket" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(salary_basket: true)

    assert_equal 0, demanded_for(member.membership)
  end

  test "all deliveries baskets" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_changes -> { demanded_for(membership) }, from: 2, to: 4 do
      membership.update!(activity_participations_demanded_annually: 4)
    end
  end

  test "1/2 of the baskets" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_changes -> { demanded_for(membership) }, from: 2, to: 1 do
      membership.update!(
        ended_on: deliveries(:thursday_5).date,
        activity_participations_demanded_annually: 2)
    end
  end

  test "1/5 of the baskets" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_changes -> { demanded_for(membership) }, from: 2, to: 0 do
      membership.update!(
        ended_on: deliveries(:thursday_1).date,
        activity_participations_demanded_annually: 2)
    end
  end

  test "half of the baskets with different cycle" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    cycle = DeliveryCycle.create!(
      name: "Odd",
      wdays: [ 4 ],
      periods_attributes: [
        { from_fy_month: 1, to_fy_month: 12, results: :odd }
      ]
    )

    assert_no_changes -> { demanded_for(membership) }, from: 2 do
      membership.update!(
        delivery_cycle: cycle,
        activity_participations_demanded_annually: 2)
    end
  end

  def apply_custom_logic
    org(activity_participations_demanded_logic: <<-LIQUID)
      {% if member.salary_basket %}
        0
      {% elsif membership.baskets < 2 %}
        1
      {% elsif membership.baskets == 2 %}
        {{ membership.full_year_activity_participations | divided_by: 2 | round }}
      {% else %}
        {{ membership.full_year_activity_participations }}
      {% endif %}
    LIQUID
  end

  test "custom logic salary basket" do
    travel_to "2024-01-01"
    apply_custom_logic
    member = members(:jane)
    member.update!(salary_basket: true)

    assert_equal 0, demanded_for(member.membership)
  end

  test "custom logic 1 basket" do
    travel_to "2024-01-01"
    apply_custom_logic
    membership = memberships(:jane)
    membership.update!(
      ended_on: deliveries(:thursday_1).date,
      activity_participations_demanded_annually: 10)

    assert_equal 1, demanded_for(membership)
  end

  test "custom logic 2 baskets" do
    travel_to "2024-01-01"
    apply_custom_logic
    membership = memberships(:jane)
    membership.update!(
      ended_on: deliveries(:thursday_2).date,
      activity_participations_demanded_annually: 10)

    assert_equal 5, demanded_for(membership)
  end

  test "custom logic 3 baskets" do
    travel_to "2024-01-01"
    apply_custom_logic
    membership = memberships(:jane)
    membership.update!(
      ended_on: deliveries(:thursday_5).date,
      activity_participations_demanded_annually: 10)

    assert_equal 10, demanded_for(membership)
  end

  def apply_depot_logic
    org(activity_participations_demanded_logic: <<-LIQUID)
      {% if membership.depot_id == #{depots(:farm).id} %}
        5
      {% else %}
        {{ membership.full_year_activity_participations }}
      {% endif %}
    LIQUID
  end

  test "custom logic with depot_id" do
    travel_to "2024-01-01"
    apply_depot_logic
    membership = memberships(:jane)

    assert_equal 2, demanded_for(membership)

    membership.update!(depot: depots(:farm))

    assert_equal 5, demanded_for(membership)
  end

  def apply_depot_group_logic(group)
    org(activity_participations_demanded_logic: <<-LIQUID)
      {% if membership.depot_group_id == #{group.id} %}
        3
      {% else %}
        {{ membership.full_year_activity_participations }}
      {% endif %}
    LIQUID
  end

  test "custom logic with depot_group_id" do
    travel_to "2024-01-01"
    group = DepotGroup.create!(names: { en: "Local" })
    depots(:bakery).update!(group: group)
    apply_depot_group_logic(group)
    membership = memberships(:jane)

    assert_equal 3, demanded_for(membership)

    membership.update!(depot: depots(:farm))

    assert_equal 2, demanded_for(Membership.find(membership.id))
  end

  test "custom logic with depot_group_id when depot has no group" do
    travel_to "2024-01-01"
    group = DepotGroup.create!(names: { en: "Local" })
    apply_depot_group_logic(group)
    membership = memberships(:jane)

    assert_equal 2, demanded_for(membership)
  end
end
