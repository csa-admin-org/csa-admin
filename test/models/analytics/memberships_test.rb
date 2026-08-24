# frozen_string_literal: true

require "test_helper"

class Analytics::MembershipsTest < ActiveSupport::TestCase
  setup do
    travel_to "2025-01-15"
  end

  test "includes salary complements and excludes zero-price complements" do
    members(:bob).update_column(:salary_basket, true)
    MembershipsBasketComplement.create!(
      membership: memberships(:bob),
      basket_complement: basket_complements(:eggs),
      quantity: 2,
      price: 6)
    MembershipsBasketComplement.create!(
      membership: memberships(:anna),
      basket_complement: basket_complements(:cheese),
      quantity: 1,
      price: 0)
    year = Analytics::Memberships.new.for(2024)

    assert_equal(
      { basket_complements(:bread).id => 1, basket_complements(:eggs).id => 2 },
      year.complement_quantities)
    assert Analytics::Memberships.new.complements?
  end

  test "counts depots and delivery cycles from all memberships including salary" do
    memberships = Analytics::Memberships.new
    year = memberships.for(2024)

    assert_equal 1, year.depot_quantities[depots(:farm).id]
    assert_equal 2, year.depot_quantities[depots(:bakery).id]
    assert memberships.depots?
    assert_not memberships.depots_capped?
    assert memberships.delivery_cycles?
    assert memberships.billing_year_divisions?
    panel = memberships.charts.find { |chart| chart.id == "depots" }
    assert_equal memberships.send(:depot_share_totals), panel.config.dig(:options, :shareTotals)

    members(:bob).update_column(:salary_basket, true)
    year = Analytics::Memberships.new.for(2024)

    assert_equal 4, year.count
    assert_equal 4, year.depot_quantities.values.sum
    assert_equal 4, year.delivery_cycle_quantities.values.sum
    assert_equal 4, year.billing_year_divisions.values.sum
  end

  test "counts memberships for a fiscal year and splits new from returning" do
    year = Analytics::Memberships.new.for(2024)

    assert_equal 4, year.count
    assert_equal 3, year.new_count
    assert_equal 1, year.returning_count
  end

  test "treats a later membership as returning after a fiscal year gap" do
    member = create_member
    create_membership(
      member: member,
      started_on: "2023-01-01",
      ended_on: "2023-12-31")
    create_membership(
      member: member,
      started_on: "2025-01-01",
      ended_on: "2025-12-31")

    year = Analytics::Memberships.new.for(2025)

    assert_equal 2, year.count
    assert_equal 0, year.new_count
    assert_equal 2, year.returning_count
  end

  test "computes closed-year renewal from renewed_at" do
    memberships(:jane).update_column(:renewed_at, Time.zone.parse("2024-12-01"))
    year = Analytics::Memberships.new.for(2024)

    assert_in_delta 50.0, year.renewal_rate, 0.01
  end

  test "hides renewal rate for the current fiscal year" do
    year = Analytics::Memberships.new.for(2025)

    assert year.in_progress?
    assert_nil year.renewal_rate
    assert_equal 1, year.count
  end

  test "includes salary baskets in size mix but not price" do
    members(:bob).update_column(:salary_basket, true)
    year = Analytics::Memberships.new.for(2024)

    assert_equal 4, year.count
    assert_equal 1, year.size_quantities[small_id]
    assert_equal 4, year.size_quantities.values.sum
    assert_in_delta((200 + 380 + 34) / 3.0, year.average_price, 0.01)
    assert_equal 200, year.median_price
  end

  test "includes zero-price basket sizes in mix but not price" do
    memberships(:bob).update_columns(basket_size_price: 0, price: 0)
    year = Analytics::Memberships.new.for(2024)

    assert_equal 4, year.count
    assert_equal 1, year.size_quantities[small_id]
    assert_equal 4, year.size_quantities.values.sum
    assert_in_delta((200 + 380 + 34) / 3.0, year.average_price, 0.01)
    assert_equal 200, year.median_price
  end

  test "includes discarded paid sizes in historical mix" do
    basket_sizes(:medium).discard
    year = Analytics::Memberships.new.for(2024)

    assert_equal 1, year.size_quantities[medium_id]
    assert_equal "Medium", Analytics::Memberships.new.sizes[medium_id].name
  end

  test "sums basket quantity in the size mix" do
    memberships(:john).update_column(:basket_quantity, 2)
    year = Analytics::Memberships.new.for(2024)

    assert_equal 2, year.size_quantities[medium_id]
  end

  test "includes complements-only memberships in the size mix" do
    size = BasketSize.create!(
      names: { "en" => "Complements only" },
      public_names: { "en" => "Complements only" },
      price: 0,
      activity_participations_demanded_annually: 0)
    create_membership(
      member: create_member,
      basket_size: size,
      started_on: "2024-01-01",
      ended_on: "2024-12-31")
    year = Analytics::Memberships.new.for(2024)

    assert_equal 1, year.size_quantities[size.id]
    assert_includes Analytics::Memberships.new.sizes.keys, size.id
  end

  test "hides extra mix when every extra is zero" do
    memberships = Analytics::Memberships.new

    assert_equal [ 0.to_d ], memberships.extras
    assert_not memberships.extras?
  end

  test "shows extra mix including the zero tier when values differ" do
    memberships(:john).update_column(:basket_price_extra, 1)
    memberships = Analytics::Memberships.new

    assert_equal [ 0.to_d, 1.to_d ], memberships.extras
    assert memberships.extras?
  end

  test "hides extra mix when only one non-zero tier is used" do
    Membership.update_all(basket_price_extra: 2)
    memberships = Analytics::Memberships.new

    assert_equal [ 2.to_d ], memberships.extras
    assert_not memberships.extras?
  end

  test "excludes salary baskets from extra mix" do
    members(:bob).update_column(:salary_basket, true)
    memberships(:john).update_column(:basket_price_extra, 1)
    memberships(:bob).update_column(:basket_price_extra, 5)
    memberships = Analytics::Memberships.new
    year = memberships.for(2024)

    assert_equal({ 0.to_d => 2, 1.to_d => 1 }, year.extra_counts)
    assert_equal [ 0.to_d, 1.to_d ], memberships.extras
  end

  test "includes memberships of discarded members" do
    members(:bob).update_columns(discarded_at: Time.current)
    year = Analytics::Memberships.new.for(2024)

    assert_equal 4, year.count
  end

  test "snaps extra amounts to the nearest catalog value" do
    memberships(:john).update_column(:basket_price_extra, 5)
    memberships = Analytics::Memberships.new
    year = memberships.for(2024)

    assert_equal({ 0.to_d => 3, 3.to_d => 1 }, year.extra_counts)
    assert_equal [ 0.to_d, 3.to_d ], memberships.extras
    assert memberships.extras?
  end

  test "snaps a negative extra to zero" do
    memberships(:john).update_column(:basket_price_extra, -3.5)
    year = Analytics::Memberships.new.for(2024)

    assert_equal 4, year.extra_counts[0.to_d]
  end

  test "caps depots at the palette size ranked by closed-year volume" do
    memberships = Analytics::Memberships.new
    year = Object.new
    year.define_singleton_method(:in_progress?) { false }
    year.define_singleton_method(:depot_quantities) { (1..9).index_with { |i| i } }

    memberships.stub(:series, [ year ]) do
      assert memberships.depots_capped?
      assert_equal [ 9, 8, 7, 6, 5, 4, 3, 2 ], memberships.send(:depot_ids)
      assert_equal [ 45 ], memberships.send(:depot_share_totals)
      assert_equal "#{Depot.model_name.human(count: 2)} (#{I18n.t("analytics.top_n", count: Analytics::PALETTE_SIZE)})",
        memberships.send(:depots_title)
    end
  end

  test "enrollment chart uses month labels and disables year sync" do
    panel = enrollment_panel

    assert_equal ("0".."12").to_a, panel.config.dig(:data, :labels)
    refute panel.config.dig(:options, :syncYear)
    assert_equal I18n.t("analytics.charts.enrollment"), panel.title
  end

  test "keeps only the last palette of enrollment years" do
    years = (2015..2026).map { |year|
      Object.new.tap { |entry|
        entry.define_singleton_method(:count) { 10 }
        entry.define_singleton_method(:new_count) { 4 }
        entry.define_singleton_method(:fiscal_year) { year }
      }
    }
    memberships = Analytics::Memberships.new

    memberships.stub(:series, years) do
      memberships.stub(:pace_counts_for, ->(_fy) { [ 0 ] * 13 }) do
        assert_equal (2019..2026).map(&:to_s), memberships.send(:pace_series).map(&:first)
        assert_equal "#{I18n.t("analytics.charts.enrollment")} (#{I18n.t("analytics.last_n", count: Analytics::PALETTE_SIZE)})",
          memberships.send(:pace_title, I18n.t("analytics.charts.enrollment"))
      end
    end
  end

  test "builds enrollment from new memberships created after the fiscal year start" do
    Membership.update_all(created_at: Time.zone.parse("2023-01-01"))
    memberships(:john).update_column(:created_at, Time.zone.parse("2024-02-01"))
    memberships(:jane).update_column(:created_at, Time.zone.parse("2024-03-15"))
    memberships(:bob).update_column(:created_at, Time.zone.parse("2024-06-01"))
    memberships(:anna).update_column(:created_at, Time.zone.parse("2024-06-01"))
    memberships(:john_future).update_column(:created_at, Time.zone.parse("2025-01-10"))

    panel = enrollment_panel

    assert_equal [ 0, 0, 0, 1, 1, 1, 3, 3, 3, 3, 3, 3, 3 ], enrollment_data(panel, "2024")
    assert_equal [ 0, 0 ] + [ nil ] * 11, enrollment_data(panel, "2025")
  end

  test "skips new memberships created during the tenant bootstrap window" do
    fy = Current.org.fiscal_year_for(2024)
    page = Analytics::Memberships.new
    wave = enrollment_row(Time.zone.parse("2024-01-28"), started_on: Date.new(2024, 1, 1))
    later = enrollment_row(Time.zone.parse("2024-03-15"), started_on: Date.new(2024, 1, 1))

    page.stub(:during, [ wave, later ]) do
      page.stub(:first_started_on_by_member, {
        wave.member_id => wave.started_on,
        later.member_id => later.started_on
      }) do
        page.stub(:bootstrap_created_on, Date.new(2024, 1, 28)) do
          assert_equal [ 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
            page.send(:pace_counts_for, fy)
        end
      end
    end
  end

  test "ignores pre-year new memberships for a non-January fiscal year" do
    org(fiscal_year_start_month: 4)
    travel_to "2025-06-15"
    fy = Current.org.fiscal_year_for(2024)
    page = Analytics::Memberships.new
    early = enrollment_row(Time.zone.parse("2024-02-10"), started_on: Date.new(2024, 4, 1))
    mid = enrollment_row(Time.zone.parse("2024-07-10"), started_on: Date.new(2024, 4, 1))

    page.stub(:during, [ early, mid ]) do
      page.stub(:first_started_on_by_member, {
        early.member_id => early.started_on,
        mid.member_id => mid.started_on
      }) do
        assert_equal [ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
          page.send(:pace_counts_for, fy)
      end
    end
  end

  test "hides extra mix when snapped extras exceed the palette" do
    memberships = Analytics::Memberships.new
    extras = (1..9).map(&:to_d)
    memberships.stub(:extras, extras) do
      assert_not memberships.extras?
    end
  end

  private

  def enrollment_panel
    Analytics::Memberships.new.charts.find { |chart| chart.id == "enrollment" }
  end

  def enrollment_data(panel, year)
    panel.config[:data][:datasets].find { |dataset| dataset[:label] == year }[:data]
  end

  def enrollment_row(created_at, started_on: Date.new(2024, 4, 1))
    Object.new.tap { |row|
      row.define_singleton_method(:created_at) { created_at }
      row.define_singleton_method(:started_on) { started_on }
      row.define_singleton_method(:member_id) { object_id }
    }
  end
end
