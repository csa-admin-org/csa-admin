# frozen_string_literal: true

require "test_helper"

class Membership::CSVExportTest < ActiveSupport::TestCase
  test "preload_csv_export matches per-membership calculations" do
    travel_to "2024-05-01"
    memberships(:jane).update!(
      basket_price_extra: 2,
      absences_included_annually: 3,
      absences_included: 3)
    memberships(:jane).baskets.update_all(price_extra: 2, calculated_price_extra: 2)

    expected = Membership.where(id: [ memberships(:jane).id, memberships(:john).id ]).map { |membership|
      [
        membership.id,
        membership.absences_included_used,
        membership.baskets_price_extra,
        membership.basket_complements_price
      ]
    }

    records = Membership.where(id: expected.map(&:first)).to_a
    Membership.preload_csv_export(records)

    assert_equal expected, records.sort_by(&:id).map { |membership|
      [
        membership.id,
        membership.absences_included_used,
        membership.baskets_price_extra,
        membership.basket_complements_price
      ]
    }
  end

  test "preload_csv_export excludes shifted source baskets from included absences" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true, basket_shifts_annually: 2)
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 1)
    source = membership.baskets.find_by!(delivery: deliveries(:thursday_5))
    target = membership.baskets.find_by!(delivery: deliveries(:thursday_6))
    BasketShift.create!(
      membership: membership,
      absence: absences(:jane_thursday_5),
      source_delivery: source.delivery,
      target_delivery: target.delivery)

    expected = membership.reload.absences_included_used
    record = Membership.find(membership.id)
    Membership.preload_csv_export([ record ])

    assert_equal expected, record.absences_included_used
  end
end
