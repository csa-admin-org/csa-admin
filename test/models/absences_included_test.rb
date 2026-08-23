# frozen_string_literal: true

require "test_helper"

class AbsencesIncludedTest < ActiveSupport::TestCase
  def included_for(membership)
    AbsencesIncluded.new(membership).count
  end

  test "full year membership uses annually" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 4)

    assert_equal 4, included_for(membership.reload)
  end

  test "half of the baskets" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      ended_on: deliveries(:thursday_5).date,
      absences_included_annually: 2)

    assert_equal 1, included_for(membership.reload)
  end

  test "rounds a short membership down to zero" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      ended_on: deliveries(:thursday_1).date,
      absences_included_annually: 2)

    assert_equal 0, included_for(membership.reload)
  end

  test "zero annually is zero" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 0)

    assert_equal 0, included_for(membership.reload)
  end

  test "empty cycle is zero" do
    travel_to "2024-01-01"
    delivery = Delivery.create!(date: "2024-04-02")
    delivery_cycle = create_delivery_cycle(wdays: [ 2 ], absences_included_annually: 2)
    membership = create_membership(
      member: create_member,
      delivery_cycle: delivery_cycle,
      started_on: "2024-01-01",
      ended_on: "2024-12-31",
      absences_included_annually: 2)

    assert_equal 2, included_for(membership.reload)

    delivery.destroy!

    assert_equal 0, included_for(membership.reload)
  end

  test "default template keeps float division" do
    result = Liquid::Template.parse(Organization.absences_included_logic_default).render(
      "membership" => {
        "baskets" => 24.0,
        "full_year_deliveries" => 49.0,
        "full_year_absences_included" => 5.0
      })

    assert_equal 2, result.to_i
  end

  test "fy month and day cliff after the 13th of the fourth fiscal month" do
    travel_to "2024-01-01"
    apply_april_cliff
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 4)

    assert_equal 4, included_for(membership.reload)

    membership.update!(started_on: "2024-04-01")
    assert_operator included_for(membership.reload), :>, 0

    membership.update!(started_on: "2024-04-13")
    assert_equal 0, included_for(membership.reload)
  end

  test "january start stays on the default formula with a cliff template" do
    travel_to "2024-01-01"
    apply_april_cliff
    membership = memberships(:jane)
    membership.update!(started_on: "2024-01-01", absences_included_annually: 4)

    assert_equal 4, included_for(membership.reload)
  end

  test "fy month is relative to a May fiscal year" do
    travel_to "2024-05-01"
    org(fiscal_year_start_month: 5)

    may = AbsencesIncluded::MembershipDrop.new(Membership.new(started_on: Date.new(2024, 5, 1)))
    assert_equal 1, may.started_fy_month
    assert_equal 1, may.started_day

    august = AbsencesIncluded::MembershipDrop.new(Membership.new(started_on: Date.new(2024, 8, 13)))
    assert_equal 4, august.started_fy_month
    assert_equal 13, august.started_day
  end

  test "custom logic with basket_size_id" do
    travel_to "2024-01-01"
    org(absences_included_logic: <<-LIQUID)
      {% if membership.basket_size_id == #{basket_sizes(:large).id} %}
        1
      {% else %}
        {{ membership.full_year_absences_included }}
      {% endif %}
    LIQUID
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 4)

    assert_equal 1, included_for(membership.reload)

    membership.update!(basket_size: basket_sizes(:small), absences_included_annually: 4)
    assert_equal 4, included_for(membership.reload)
  end

  test "garbage and negative renders are clamped to zero" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 4)

    org(absences_included_logic: "nope")
    assert_equal 0, included_for(membership.reload)

    org(absences_included_logic: "-2")
    assert_equal 0, included_for(membership.reload)
  end

  test "skips the write when the absence feature is off" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update_column(:absences_included, 7)
    org(features: Current.org.features - [ :absence ])

    membership.update!(absences_included_annually: 4)

    assert_equal 7, membership.reload.absences_included
  end

  private

  def apply_april_cliff
    org(absences_included_logic: <<-LIQUID)
      {% if membership.started_fy_month > 4 or membership.started_fy_month == 4 and membership.started_day >= 13 %}
        0
      {% else %}
        {{ membership.baskets | divided_by: membership.full_year_deliveries | times: membership.full_year_absences_included | round }}
      {% endif %}
    LIQUID
  end
end
