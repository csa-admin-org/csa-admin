# frozen_string_literal: true

require "test_helper"

class Membership::AuditingTest < ActiveSupport::TestCase
  test "audits changes to tracked attributes" do
    membership = memberships(:john)

    assert_difference(-> { Audit.where(auditable: membership).count }, 1) do
      membership.update!(basket_quantity: 2)
    end

    audit = membership.audits.last
    assert_equal({ "basket_quantity" => [ 1, 2 ] }, audit.audited_changes)
  end

  test "audits changes to basket_size_id" do
    membership = memberships(:john)
    old_basket_size = membership.basket_size
    new_basket_size = basket_sizes(:small)

    assert_difference(-> { Audit.where(auditable: membership).count }, 1) do
      membership.update!(basket_size_id: new_basket_size.id, basket_size_price: new_basket_size.price)
    end

    audit = membership.audits.last
    assert_equal old_basket_size.id, audit.audited_changes["basket_size_id"].first
    assert_equal new_basket_size.id, audit.audited_changes["basket_size_id"].last
  end

  test "audits changes to depot_id" do
    membership = memberships(:john)
    old_depot = membership.depot
    new_depot = depots(:bakery)

    assert_difference(-> { Audit.where(auditable: membership).count }, 1) do
      membership.update!(depot_id: new_depot.id, depot_price: new_depot.price)
    end

    audit = membership.audits.last
    assert_equal old_depot.id, audit.audited_changes["depot_id"].first
    assert_equal new_depot.id, audit.audited_changes["depot_id"].last
  end

  test "audits changes to memberships_basket_complements when adding" do
    membership = memberships(:john)
    complement = basket_complements(:eggs)

    assert_difference(-> { Audit.where(auditable: membership).count }, 1) do
      membership.update!(
        memberships_basket_complements_attributes: [
          { basket_complement_id: complement.id, quantity: 2, price: complement.price }
        ]
      )
    end

    audit = membership.audits.last
    assert audit.audited_changes.key?("memberships_basket_complements")
    changes = audit.audited_changes["memberships_basket_complements"]
    assert_empty changes.first # was empty
    assert_equal 1, changes.last.size
    assert_equal complement.id, changes.last.first["basket_complement_id"]
    assert_equal 2, changes.last.first["quantity"]
  end

  test "audits removal of memberships_basket_complements" do
    membership = memberships(:jane)
    mbc = membership.memberships_basket_complements.first

    assert_difference(-> { Audit.where(auditable: membership).count }, 1) do
      membership.update!(
        memberships_basket_complements_attributes: [
          { id: mbc.id, _destroy: "1" }
        ]
      )
    end

    audit = membership.audits.last
    assert audit.audited_changes.key?("memberships_basket_complements")
    changes = audit.audited_changes["memberships_basket_complements"]
    assert_equal 1, changes.first.size # had one complement
    assert_empty changes.last # now empty
  end

  test "does not audit when no attribute changes" do
    membership = memberships(:john)

    assert_no_difference(-> { Audit.where(auditable: membership).count }) do
      membership.save!
    end
  end

  test "records session when auditing" do
    travel_to "2024-01-01"
    admin = admins(:super)
    session = create_session(admin)
    Current.session = session

    membership = memberships(:john)

    assert_difference(-> { Audit.where(auditable: membership).count }, 1) do
      membership.update!(basket_quantity: 2)
    end

    audit = membership.audits.last
    assert_equal session, audit.session
    assert_equal admin, audit.actor
  end

  test "records new_config_from in metadata when auditing" do
    membership = memberships(:john)
    config_date = membership.started_on + 1.week

    membership.new_config_from = config_date
    membership.update!(basket_quantity: 2)

    audit = membership.audits.last
    assert_equal config_date.to_s, audit.metadata["new_config_from"]
  end

  test "records new_config_from in metadata when auditing basket complements" do
    membership = memberships(:john)
    complement = basket_complements(:eggs)
    config_date = membership.started_on + 2.weeks

    membership.new_config_from = config_date
    membership.update!(
      memberships_basket_complements_attributes: [
        { basket_complement_id: complement.id, quantity: 1, price: complement.price }
      ]
    )

    audit = membership.audits.last
    assert_equal config_date.to_s, audit.metadata["new_config_from"]
  end

  test "does not record new_config_from for non-config attributes" do
    membership = memberships(:john)
    config_date = membership.started_on + 1.week

    membership.new_config_from = config_date
    membership.update!(renewal_note: "Some note about renewal")

    audit = membership.audits.last
    assert_nil audit.metadata["new_config_from"]
  end

  test "combines attribute and complement changes into a single audit" do
    membership = memberships(:john)
    complement = basket_complements(:eggs)
    new_depot = depots(:bakery)

    assert_difference(-> { Audit.where(auditable: membership).count }, 1) do
      membership.update!(
        depot_id: new_depot.id,
        depot_price: new_depot.price,
        memberships_basket_complements_attributes: [
          { basket_complement_id: complement.id, quantity: 1, price: complement.price }
        ]
      )
    end

    audit = membership.audits.last
    # Both attribute and complement changes in same audit
    assert audit.audited_changes.key?("depot_id"), "Expected depot_id in audited changes"
    assert audit.audited_changes.key?("memberships_basket_complements"), "Expected memberships_basket_complements in audited changes"
  end
end
