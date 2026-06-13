# frozen_string_literal: true

require "test_helper"

class Member::AuditingTest < ActiveSupport::TestCase
  test "audited waiting membership attribute names are translated" do
    attrs = %w[
      waiting_started_at
      waiting_basket_size_id
      waiting_depot_id
      waiting_delivery_cycle_id
      waiting_basket_price_extra
      waiting_activity_participations_demanded_annually
      waiting_billing_year_division
      waiting_basket_complements
      waiting_alternative_depot_ids
    ]

    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        attrs.each do |attr|
          assert_not_equal \
            attr.humanize,
            Member.human_attribute_name(attr),
            "#{attr} is missing a #{locale} translation"
        end
      end
    end
  end

  test "audits changes to waiting membership attributes" do
    member = members(:aria)
    new_depot = depots(:bakery)

    assert_difference(-> { Audit.where(auditable: member).count }, 1) do
      member.update!(
        waiting_depot: new_depot,
        waiting_basket_price_extra: 5,
        waiting_activity_participations_demanded_annually: 3)
    end

    audit = member.audits.last
    assert_equal [ depots(:farm).id, new_depot.id ], audit.audited_changes["waiting_depot_id"]
    assert_equal [ 0, 5 ], audit.audited_changes["waiting_basket_price_extra"].map(&:to_i)
    assert_equal [ 0, 3 ], audit.audited_changes["waiting_activity_participations_demanded_annually"]
  end

  test "audits clearing waiting membership attributes and joins" do
    member = members(:aria)
    member.update_columns(
      waiting_started_at: Time.zone.parse("2024-04-01"),
      waiting_basket_size_id: basket_sizes(:medium).id,
      waiting_depot_id: depots(:farm).id,
      waiting_delivery_cycle_id: delivery_cycles(:mondays).id,
      waiting_basket_price_extra: 2,
      waiting_activity_participations_demanded_annually: 4,
      waiting_billing_year_division: 1)
    complement = member.members_basket_complements.create!(
      basket_complement: basket_complements(:bread),
      quantity: 2)
    member.waiting_alternative_depot_ids = [ depots(:bakery).id ]
    member.audits.delete_all

    assert_difference(-> { Audit.where(auditable: member).count }, 1) do
      member.clear_waiting_membership_attributes!
    end

    audit = member.audits.last
    assert_equal [ basket_sizes(:medium).id, nil ], audit.audited_changes["waiting_basket_size_id"]
    assert_equal [ depots(:farm).id, nil ], audit.audited_changes["waiting_depot_id"]
    assert_equal [ delivery_cycles(:mondays).id, nil ], audit.audited_changes["waiting_delivery_cycle_id"]
    assert_equal [ 2, nil ], audit.audited_changes["waiting_basket_price_extra"].map { |v| v&.to_i }
    assert_equal [ 4, nil ], audit.audited_changes["waiting_activity_participations_demanded_annually"]
    assert_equal [ 1, nil ], audit.audited_changes["waiting_billing_year_division"]

    complement_change = audit.audited_changes["waiting_basket_complements"]
    assert_equal complement.id, complement_change.first.first["id"]
    assert_equal basket_complements(:bread).id, complement_change.first.first["basket_complement_id"]
    assert_empty complement_change.last

    assert_equal [ [ depots(:bakery).id ], [] ], audit.audited_changes["waiting_alternative_depot_ids"]
  end
end
