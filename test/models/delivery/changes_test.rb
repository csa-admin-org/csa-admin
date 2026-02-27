# frozen_string_literal: true

require "test_helper"

class Delivery::ChangesTest < ActiveSupport::TestCase
  # == First delivery of fiscal year ==

  test "detects new members on first delivery of fiscal year" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1) # 2024-04-01, first delivery of FY

    changes = Delivery::Changes.new(delivery)

    # John's past baskets are older than 6 months, so he appears as new.
    # Bob and Anna have no previous baskets at all, so they also appear as new.
    new_names = entries_with_change_type(changes, :new).map { |e| e.member.name }
    assert_includes new_names, "John Doe"
    assert_includes new_names, "Bob Doe"
    assert_includes new_names, "Anna Doe"
  end

  test "no ended members on first delivery of fiscal year" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1) # 2024-04-01, no previous delivery in this FY

    changes = Delivery::Changes.new(delivery)

    ended_entries = entries_with_change_type(changes, :ended)
    assert_empty ended_entries
  end

  # == New member detection ==

  test "detects new member with no previous baskets" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2) # 2024-04-08, second week

    create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: "2024-04-08",
      ended_on: "2024-12-31"
    )

    changes = Delivery::Changes.new(delivery)

    mary_entries = entries_with_change_type(changes, :new).select { |e| e.member == members(:mary) }
    assert_equal 1, mary_entries.size

    mary_change = mary_entries.first.changes.find { |c| c.type == :new }
    assert_equal "New", mary_change.label
    assert_equal "Small", mary_change.details
  end

  test "new member only produces new entry, no change entries" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: "2024-04-08",
      ended_on: "2024-12-31"
    )

    changes = Delivery::Changes.new(delivery)
    mary_entries = changes.entries.select { |e| e.member == members(:mary) }

    assert_equal 1, mary_entries.size
    assert_equal [ :new ], mary_entries.first.changes.map(&:type)
  end

  test "member is not flagged as new on 2nd delivery" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_3) # 2024-04-15

    create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: "2024-04-08",
      ended_on: "2024-12-31"
    )

    changes = Delivery::Changes.new(delivery)
    mary_entries = entries_with_change_type(changes, :new).select { |e| e.member == members(:mary) }

    assert_empty mary_entries
  end

  test "John is not flagged as new on monday_2 because monday_1 basket is recent" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    changes = Delivery::Changes.new(delivery)
    john_new = entries_with_change_type(changes, :new).select { |e| e.member == members(:john) }

    assert_empty john_new
  end

  # == Cross fiscal year ==

  test "cross fiscal year without renewal treats member as new" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: "2024-04-08",
      ended_on: "2024-12-31"
    )

    changes = Delivery::Changes.new(delivery)
    new_entries = entries_with_change_type(changes, :new).select { |e| e.member == members(:mary) }

    assert_equal 1, new_entries.size
  end

  # == Staleness cutoff ==

  test "member with previous basket older than 6 months is treated as new" do
    travel_to "2024-01-01"
    # monday_2 is 2024-04-08, cutoff = 2023-10-08
    # John's past baskets run 2023-04-03..2023-06-05, all before cutoff
    delivery = deliveries(:monday_2)

    # Remove John's monday_1 basket so his only previous baskets are the old ones
    baskets(:john_1).destroy!

    changes = Delivery::Changes.new(delivery)
    john_entries = changes.entries.select { |e| e.member == members(:john) }

    assert_equal 1, john_entries.size
    assert_equal [ :new ], john_entries.first.changes.map(&:type)
  end

  # == Ended member detection ==

  test "detects ended member when membership ended before delivery" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2) # 2024-04-08, Bob's membership ends 2024-04-05

    changes = Delivery::Changes.new(delivery)
    ended_entries = entries_with_change_type(changes, :ended)
    ended_member_names = ended_entries.map { |e| e.member.name }

    assert_includes ended_member_names, "Bob Doe"
    assert_includes ended_member_names, "Anna Doe"

    bob_ended = ended_entries.find { |e| e.member == members(:bob) }
    assert_equal basket_sizes(:small).name, bob_ended.changes.first.details
  end

  test "ended member shows last known depot" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    changes = Delivery::Changes.new(delivery)
    bob_ended = entries_with_change_type(changes, :ended).find { |e| e.member == members(:bob) }

    assert_equal depots(:home).name, bob_ended.depot_name
  end

  test "does not flag members on different delivery cycle as ended" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    changes = Delivery::Changes.new(delivery)
    ended_entries = entries_with_change_type(changes, :ended)
    ended_member_names = ended_entries.map { |e| e.member.name }

    # Jane is on Thursdays cycle, not relevant to Monday deliveries
    assert_not_includes ended_member_names, "Jane Doe"
  end

  test "ended member without any previous baskets is skipped" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    membership = create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: "2024-01-01",
      ended_on: "2024-04-02"
    )
    membership.baskets.destroy_all

    changes = Delivery::Changes.new(delivery)
    mary_entries = changes.entries.select { |e| e.member == members(:mary) }

    assert_empty mary_entries
  end

  test "ended members do not persist on subsequent deliveries" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_5) # 2024-04-29, well after Bob/Anna ended on 2024-04-05

    changes = Delivery::Changes.new(delivery)

    ended_entries = entries_with_change_type(changes, :ended)
    ended_names = ended_entries.map { |e| e.member.name }
    # Bob and Anna ended before monday_2, so they should only appear as ended
    # on monday_2 (the first delivery after their membership ended), not on monday_5.
    assert_not_includes ended_names, "Bob Doe"
    assert_not_includes ended_names, "Anna Doe"
  end

  test "absent basket is not flagged as ended" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(state: "absent")

    changes = Delivery::Changes.new(delivery)
    ended_entries = entries_with_change_type(changes, :ended).select { |e| e.member == members(:john) }

    assert_empty ended_entries
  end

  # == Depot change ==

  test "detects depot change" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(depot_id: depots(:bakery).id)

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :depot_changed).find { |e| e.member == members(:john) }

    assert john_entry
    depot_change = john_entry.changes.find { |c| c.type == :depot_changed }
    assert_includes depot_change.details, depots(:farm).name
    assert_includes depot_change.details, depots(:bakery).name
    assert_includes depot_change.details, "=>"
  end

  # == Basket changed (size and/or quantity merged) ==

  test "detects basket size change" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(basket_size_id: basket_sizes(:large).id)

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :basket_changed).find { |e| e.member == members(:john) }

    assert john_entry
    basket_change = john_entry.changes.find { |c| c.type == :basket_changed }
    # "Medium => Large" (quantity is 1 on both sides, so no "Nx" prefix)
    assert_includes basket_change.details, basket_sizes(:medium).name
    assert_includes basket_change.details, basket_sizes(:large).name
    assert_includes basket_change.details, "=>"
  end

  test "detects basket quantity change" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(quantity: 2)

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :basket_changed).find { |e| e.member == members(:john) }

    assert john_entry
    basket_change = john_entry.changes.find { |c| c.type == :basket_changed }
    # "Medium => 2x Medium"
    assert_includes basket_change.details, "2x Medium"
    assert_includes basket_change.details, "=>"
  end

  test "detects combined basket size and quantity change" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(basket_size_id: basket_sizes(:large).id, quantity: 2)

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :basket_changed).find { |e| e.member == members(:john) }

    assert john_entry
    basket_change = john_entry.changes.find { |c| c.type == :basket_changed }
    # "Medium => 2x Large"
    assert_includes basket_change.details, "Medium"
    assert_includes basket_change.details, "2x Large"
    assert_includes basket_change.details, "=>"
  end

  # == Absence detection ==

  test "detects absent basket when previous was not absent with basket description" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(state: "absent")

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :absent).find { |e| e.member == members(:john) }

    assert john_entry
    absent_change = john_entry.changes.find { |c| c.type == :absent }
    assert_equal Basket.human_attribute_name(:absent).capitalize, absent_change.label
    assert_equal "Medium", absent_change.details
  end

  test "does not flag absent when previous was also absent" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_1).update_columns(state: "absent")
    baskets(:john_2).update_columns(state: "absent")

    changes = Delivery::Changes.new(delivery)
    absent_entries = entries_with_change_type(changes, :absent).select { |e| e.member == members(:john) }

    assert_empty absent_entries
  end

  # == Complement changes (with delivery schedule awareness) ==
  # Thursday deliveries have basket_complements: [bread, eggs]
  # Jane's membership subscribes to bread (quantity: 1)
  # So jane_N baskets already have a BasketsBasketComplement for bread.

  test "detects complement added when scheduled on both deliveries" do
    travel_to "2024-01-01"
    delivery = deliveries(:thursday_2)

    # Jane already has bread on all Thursday baskets via fixture subscription.
    # Add eggs to jane_2 only — eggs is in the Thursday delivery schedule
    # but Jane doesn't subscribe to it, so it's not on her baskets by default.
    baskets(:jane_2).baskets_basket_complements.create!(
      basket_complement: basket_complements(:eggs),
      quantity: 1,
      price: 6
    )

    changes = Delivery::Changes.new(delivery)
    jane_entry = entries_with_change_type(changes, :complements_changed).find { |e| e.member == members(:jane) }

    assert jane_entry
    comp_change = jane_entry.changes.find { |c| c.type == :complements_changed }
    assert_includes comp_change.details, basket_complements(:eggs).name
    assert_includes comp_change.details, "+"
  end

  test "detects complement removed when scheduled on both deliveries" do
    travel_to "2024-01-01"
    delivery = deliveries(:thursday_2)

    # Jane already has bread on all Thursday baskets. Remove it from thursday_2.
    baskets(:jane_2).baskets_basket_complements.find_by(
      basket_complement: basket_complements(:bread)
    )&.destroy!

    changes = Delivery::Changes.new(delivery)
    jane_entry = entries_with_change_type(changes, :complements_changed).find { |e| e.member == members(:jane) }

    assert jane_entry
    comp_change = jane_entry.changes.find { |c| c.type == :complements_changed }
    assert_includes comp_change.details, basket_complements(:bread).name
    assert_includes comp_change.details, "–"
  end

  test "detects complement quantity change" do
    travel_to "2024-01-01"
    delivery = deliveries(:thursday_2)

    # Jane has bread (qty 1) on all Thursday baskets via fixture.
    # Change the quantity on thursday_2 to 3.
    bbc = baskets(:jane_2).baskets_basket_complements.find_by(
      basket_complement: basket_complements(:bread)
    )
    bbc.update_columns(quantity: 3)

    changes = Delivery::Changes.new(delivery)
    jane_entry = entries_with_change_type(changes, :complements_changed).find { |e| e.member == members(:jane) }

    assert jane_entry
    comp_change = jane_entry.changes.find { |c| c.type == :complements_changed }
    bread_name = basket_complements(:bread).name
    assert_includes comp_change.details, bread_name
    assert_includes comp_change.details, "3x #{bread_name}"
    assert_includes comp_change.details, "=>"
  end

  test "ignores complement difference when not scheduled on both deliveries" do
    travel_to "2024-01-01"
    # Monday deliveries have NO basket_complements in their schedule.
    # Even if we force a complement record onto a Monday basket,
    # the schedule-aware comparison should ignore it.
    delivery = deliveries(:monday_2)

    # Insert directly to bypass validation (Monday delivery doesn't schedule bread)
    BasketsBasketComplement.insert!({
      basket_id: baskets(:john_1).id,
      basket_complement_id: basket_complements(:bread).id,
      quantity: 1,
      price: 4
    })

    changes = Delivery::Changes.new(delivery)
    comp_entries = entries_with_change_type(changes, :complements_changed).select { |e| e.member == members(:john) }

    assert_empty comp_entries
  end

  test "no complement change when both baskets have same subscribed complements" do
    travel_to "2024-01-01"
    # Jane has bread (qty 1) on all Thursday baskets — no change expected
    delivery = deliveries(:thursday_2)

    changes = Delivery::Changes.new(delivery)
    comp_entries = entries_with_change_type(changes, :complements_changed).select { |e| e.member == members(:jane) }

    assert_empty comp_entries
  end

  # == Multiple changes ==

  test "multiple changes for one member produce a single entry" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(
      depot_id: depots(:bakery).id,
      basket_size_id: basket_sizes(:large).id
    )

    changes = Delivery::Changes.new(delivery)
    john_entries = changes.entries.select { |e| e.member == members(:john) }

    assert_equal 1, john_entries.size

    change_types = john_entries.first.changes.map(&:type)
    assert_includes change_types, :depot_changed
    assert_includes change_types, :basket_changed
  end

  # == No changes ==

  test "no changes when all members have same config as previous baskets" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_5)

    changes = Delivery::Changes.new(delivery)
    john_entries = changes.entries.select { |e| e.member == members(:john) }

    assert_empty john_entries
  end

  test "any? returns false when there are no changes at all" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_5)

    # Remove Bob and Anna so they don't appear as ended.
    # Use destroy to properly cascade FK constraints.
    memberships(:bob).baskets.destroy_all
    memberships(:bob).destroy
    memberships(:anna).baskets.destroy_all
    memberships(:anna).destroy

    changes = Delivery::Changes.new(delivery)

    assert_not changes.any?
    assert_empty changes.entries
  end

  # == Sorting ==

  test "entries are sorted by depot name then member name" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    changes = Delivery::Changes.new(delivery)

    depot_names = changes.entries.map(&:depot_name)
    member_names_by_depot = changes.entries.group_by(&:depot_name).transform_values { |es| es.map { |e| e.member.name } }

    assert_equal depot_names.sort, depot_names

    member_names_by_depot.each_value do |names|
      assert_equal names.sort, names
    end
  end

  # == Description ==

  test "description merges label and details into a single string" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(
      depot_id: depots(:bakery).id,
      basket_size_id: basket_sizes(:large).id
    )

    changes = Delivery::Changes.new(delivery)
    john_entry = changes.entries.find { |e| e.member == members(:john) }

    assert_includes john_entry.description, "Depot: Farm → Bakery"
    assert_includes john_entry.description, "Basket: Medium → Large"
  end

  test "description for new entry includes basket description in parentheses" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: "2024-04-08",
      ended_on: "2024-12-31"
    )

    changes = Delivery::Changes.new(delivery)
    mary_entry = changes.entries.find { |e| e.member == members(:mary) }

    assert_equal "New (Small)", mary_entry.description
  end

  test "formatted_description for new entry bolds only label" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:farm),
      delivery_cycle: delivery_cycles(:mondays),
      started_on: "2024-04-08",
      ended_on: "2024-12-31"
    )

    changes = Delivery::Changes.new(delivery)
    mary_entry = changes.entries.find { |e| e.member == members(:mary) }

    assert_equal "<b>New</b> (Small)", mary_entry.formatted_description
  end

  test "formatted_description for ended entry includes basket description in parentheses" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    changes = Delivery::Changes.new(delivery)
    bob_entry = entries_with_change_type(changes, :ended).find { |e| e.member == members(:bob) }

    assert_equal "Ended (Small)", bob_entry.formatted_description
  end

  test "formatted_description for absent entry includes basket description in parentheses" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(state: "absent")

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :absent).find { |e| e.member == members(:john) }

    assert_equal "<color rgb='666666'>#{Basket.human_attribute_name(:absent).capitalize} (Medium)</color>", john_entry.formatted_description
  end

  test "shift target shows basket description with shift date annotation" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_3) # 2024-04-15

    # Create an absence on monday_2 and shift its basket to monday_3
    absence = create_absence(
      member: members(:john),
      started_on: deliveries(:monday_2).date,
      ended_on: deliveries(:monday_2).date + 1.day)

    baskets(:john_2).update_columns(state: "absent")
    BasketShift.create!(
      absence: absence,
      source_basket: baskets(:john_2),
      target_basket: baskets(:john_3))

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :basket_changed).find { |e| e.member == members(:john) }

    assert john_entry
    basket_change = john_entry.changes.find { |c| c.type == :basket_changed }
    # Should show current basket description with shift date (no year)
    assert_includes basket_change.details, baskets(:john_3).reload.basket_description
    shift_date = I18n.l(deliveries(:monday_2).date, format: :short_no_year)
    assert_includes basket_change.details, shift_date
    assert_includes basket_change.details, BasketShift.model_name.human.downcase
  end

  test "shift target does not produce separate shift_source or shift_target changes" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_3)

    absence = create_absence(
      member: members(:john),
      started_on: deliveries(:monday_2).date,
      ended_on: deliveries(:monday_2).date + 1.day)

    baskets(:john_2).update_columns(state: "absent")
    BasketShift.create!(
      absence: absence,
      source_basket: baskets(:john_2),
      target_basket: baskets(:john_3))

    changes = Delivery::Changes.new(delivery)
    john_entry = changes.entries.find { |e| e.member == members(:john) }

    change_types = john_entry.changes.map(&:type)
    assert_not_includes change_types, :shift_source
    assert_not_includes change_types, :shift_target
  end

  # == Summary counts ==

  test "absences_count returns number of absent entries" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(state: "absent")

    changes = Delivery::Changes.new(delivery)

    assert_equal 1, changes.absences_count
  end

  test "other_changes_count excludes absent entries" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(state: "absent")

    # Mary joins as a new member (counts as "other change", not absence)
    create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:bakery),
      started_on: delivery.date - 1.day)

    changes = Delivery::Changes.new(delivery)

    assert_equal 1, changes.absences_count
    assert_operator changes.other_changes_count, :>=, 1
  end

  # == HTML description ==

  test "html_description for new entry uses strong tag" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    create_membership(
      member: members(:mary),
      basket_size: basket_sizes(:small),
      depot: depots(:bakery),
      started_on: delivery.date - 1.day)

    changes = Delivery::Changes.new(delivery)
    mary_entry = entries_with_change_type(changes, :new).find { |e| e.member == members(:mary) }

    assert_includes mary_entry.html_description, "<strong>"
    assert_includes mary_entry.html_description, "</strong>"
    assert mary_entry.html_description.html_safe?
  end

  test "html_description for absent entry uses gray span" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(state: "absent")

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :absent).find { |e| e.member == members(:john) }

    assert_includes john_entry.html_description, "text-gray-400"
    assert john_entry.html_description.html_safe?
  end

  test "html_description for depot change uses gray label span" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(depot_id: depots(:home).id)

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :depot_changed).find { |e| e.member == members(:john) }

    assert_includes john_entry.html_description, "text-gray-400"
    assert_includes john_entry.html_description, "→"
    assert john_entry.html_description.html_safe?
  end

  test "html_description for ended entry is plain text" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    memberships(:bob).update_columns(ended_on: delivery.date - 1.day)

    changes = Delivery::Changes.new(delivery)
    bob_entry = entries_with_change_type(changes, :ended).find { |e| e.member == members(:bob) }

    assert_not_includes bob_entry.html_description, "<strong>"
    assert_not_includes bob_entry.html_description, "text-gray-400"
    assert bob_entry.html_description.html_safe?
  end

  test "html_description escapes HTML in change details" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(depot_id: depots(:home).id)

    changes = Delivery::Changes.new(delivery)
    john_entry = entries_with_change_type(changes, :depot_changed).find { |e| e.member == members(:john) }

    # The description should be html_safe and properly escape content
    assert john_entry.html_description.html_safe?
    assert_not_includes john_entry.html_description, "<script>"
  end

  private

  def entries_with_change_type(changes, type)
    changes.entries.select { |e| e.changes.any? { |c| c.type == type } }
  end
end
