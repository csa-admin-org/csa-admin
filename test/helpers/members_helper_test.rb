# frozen_string_literal: true

require "test_helper"

class MembersHelperTest < ActionView::TestCase
  test "deliveries_count_range_with_absences scalar: shows count with absence" do
    assert_equal "26 (-2)", deliveries_count_range_with_absences(26, 2)
  end

  test "deliveries_count_range_with_absences scalar: no absence annotation when zero absences" do
    assert_equal "26", deliveries_count_range_with_absences(26, 0)
  end

  test "deliveries_count_range_with_absences scalar: zero count suppresses absence annotation" do
    assert_equal "0", deliveries_count_range_with_absences(0, 2)
  end

  test "deliveries_count_range_with_absences array: single value with absence" do
    assert_equal "26 (-2)", deliveries_count_range_with_absences([ 26 ], [ 2 ])
  end

  test "deliveries_count_range_with_absences array: range of counts with range of absences" do
    assert_equal "24-26 (-1-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 1, 2 ])
  end

  test "deliveries_count_range_with_absences array: uniform absence shown as single value" do
    assert_equal "24-26 (-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 2, 2 ])
  end

  test "deliveries_count_range_with_absences array: no annotation when all absences are zero" do
    assert_equal "26", deliveries_count_range_with_absences([ 26 ], [ 0 ])
  end

  test "deliveries_count_range_with_absences array: skips zero absences in mixed cycles" do
    assert_equal "24-26 (-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 0, 2 ])
  end

  test "depot_details does not show delivery count when depot has same cycles in different order" do
    farm = depots(:farm)
    dc_mondays = delivery_cycles(:mondays)
    dc_thursdays = delivery_cycles(:thursdays)
    dc_all = delivery_cycles(:all)

    @billable_deliveries_counts = [ 10, 20 ]
    @depots_delivery_cycles = [ dc_all, dc_thursdays, dc_mondays ]

    assert_equal(@depots_delivery_cycles.map(&:id).sort, farm.delivery_cycle_ids.sort)
    assert_equal farm.full_address, depot_details(farm)
  end

  test "depot_details shows delivery count when depot has genuinely different cycles" do
    farm = depots(:farm)
    dc_mondays = delivery_cycles(:mondays)
    dc_thursdays = delivery_cycles(:thursdays)
    dc_all = delivery_cycles(:all)

    @billable_deliveries_counts = [ 10, 20 ]
    @depots_delivery_cycles = [ dc_mondays, dc_thursdays, dc_all ]

    farm.delivery_cycle_ids = [ dc_mondays.id ]

    assert_not_equal farm.full_address, depot_details(farm)
  end

  test "depot map location uses coordinates when present" do
    farm = depots(:farm)
    farm.latitude = 46.5191
    farm.longitude = 6.5668

    assert_equal "46.5191,6.5668", depot_map_location(farm)
    assert_equal "https://www.google.com/maps?q=46.5191,6.5668", depot_google_maps_url(depot_map_location(farm))
  end

  test "depot map location falls back to address" do
    farm = depots(:farm)

    assert_equal "42 Nowhere, 1234 Unknown", depot_map_location(farm)
  end

  test "members_collection pins last-used members and does not duplicate them" do
    jane = members(:jane)
    john = members(:john)
    insert_shop_order(jane, 2.days.ago)
    shop_orders(:john).update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)

    recent, others = members_collection(featured: Shop::Order.all_without_cart)

    assert_equal I18n.t("active_admin.searchable_select.recent"), recent.first
    assert_equal [ john.id, jane.id ], recent.last.map(&:second)
    assert recent.last.all? { |_, _, html| html.dig(:data, :recent) }
    assert_not_includes others.last.map(&:second), john.id
    assert_not_includes others.last.map(&:second), jane.id
    assert_includes others.last.map(&:second), members(:bob).id
  end

  test "members_collection caps the recent group at 8" do
    newest = Array.new(9) { |index|
      Member.create!(
        name: "Recent #{index}",
        street: "Nowhere #{index}",
        city: "City",
        zip: "1234",
        trial_baskets_count: 0)
    }
    newest.each_with_index { |member, index| insert_shop_order(member, index.hours.ago) }

    recent, others = members_collection(featured: Shop::Order.where(member: newest))

    assert_equal newest.first(8).map(&:id), recent.last.map(&:second)
    assert_includes others.last.map(&:second), newest.last.id
  end

  test "members_collection omits the recent group when there is nothing to pin" do
    collection = members_collection(featured: Shop::Order.none)

    assert_kind_of ActiveRecord::Relation, collection
    assert_equal Member.kept.order_by_name.pluck(:id), collection.pluck(:id)
  end

  test "members_collection omits the recent group when it covers the visible list" do
    john = members(:john)
    shop_orders(:john).update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)

    collection = members_collection(
      Shop::Order.where(member_id: john.id),
      featured: Shop::Order.all_without_cart)

    assert_kind_of ActiveRecord::Relation, collection
    assert_equal [ john.id ], collection.pluck(:id)
  end

  test "members_collection drops a discarded member from the recent group" do
    jane = members(:jane)
    john = members(:john)
    insert_shop_order(jane, 1.hour.ago)
    shop_orders(:john).update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
    jane.discard

    recent, = members_collection(featured: Shop::Order.all_without_cart)

    assert_equal [ john.id ], recent.last.map(&:second)
    assert_not_includes recent.last.map(&:second), jane.id
  end

  test "members_collection still restricts options to the given relation" do
    collection = members_collection(Shop::Order.where(member_id: members(:john).id))

    assert_equal [ members(:john).id ], collection.pluck(:id)
  end

  test "members_collection plucks distinct member ids without index-table joins or created_at order" do
    newsletter = newsletters(:sent)
    jane = members(:jane)
    insert_newsletter_delivery(newsletter, jane, emails: %w[jane@doe.com extra@doe.com])

    relation = admin_index_mail_deliveries(newsletter)
    queries = collect_sql_queries { @members = members_collection(relation) }
    plucks = member_id_distinct_plucks(queries)

    assert_equal 1, plucks.size, "expected one DISTINCT member_id pluck, got:\n#{queries.join("\n")}"
    assert_lean_member_id_pluck plucks.first
    assert_equal [ jane.id, members(:john).id ], @members.pluck(:id)
  end

  test "members_collection member_id pluck stays a single lean query as deliveries grow" do
    newsletter = newsletters(:sent)
    jane = members(:jane)
    insert_newsletter_deliveries(newsletter, [ jane, members(:john) ], 8)

    few_queries = collect_sql_queries { members_collection(admin_index_mail_deliveries(newsletter)) }
    insert_newsletter_deliveries(newsletter, [ jane, members(:john) ], 20, start_at: 2.hours.ago)
    many_queries = collect_sql_queries { members_collection(admin_index_mail_deliveries(newsletter)) }

    few_plucks = member_id_distinct_plucks(few_queries)
    many_plucks = member_id_distinct_plucks(many_queries)

    assert_equal 1, few_plucks.size
    assert_equal 1, many_plucks.size
    assert_lean_member_id_pluck few_plucks.first
    assert_lean_member_id_pluck many_plucks.first
    assert_equal few_plucks.first.gsub(/\d+/, "N"), many_plucks.first.gsub(/\d+/, "N")
  end

  test "depot map icon location falls back to address when maps feature is off" do
    org(features: Current.org.features - [ :maps ])
    farm = depots(:farm)

    assert_equal "42 Nowhere, 1234 Unknown", depot_map_icon_location(farm)
  end

  test "depot map icon location uses coordinates for mapped depots when maps feature is on" do
    org(features: Current.org.features | [ :maps ])
    farm = depots(:farm)
    farm.maps_visible = true
    farm.latitude = 46.5191
    farm.longitude = 6.5668

    assert_equal "46.5191,6.5668", depot_map_icon_location(farm)
  end

  test "depot map icon location does not fall back to address for hidden map depots" do
    org(features: Current.org.features | [ :maps ])
    farm = depots(:farm)
    farm.maps_visible = false
    farm.latitude = 46.5191
    farm.longitude = 6.5668

    assert_nil depot_map_icon_location(farm)
  end

  test "depot map icon location does not fall back to address for mapped depots without coordinates" do
    org(features: Current.org.features | [ :maps ])
    farm = depots(:farm)
    farm.maps_visible = true

    assert_nil depot_map_icon_location(farm)
  end

  test "depot map title stays human-readable when coordinates are present" do
    farm = depots(:farm)
    farm.latitude = 46.5191
    farm.longitude = 6.5668

    assert_equal "42 Nowhere, 1234 Unknown", depot_map_title(farm)
  end

  test "display_member_city_with_zip shows city and zip" do
    assert_equal "Lausanne (1000)", display_member_city_with_zip(member_address("Lausanne", "1000"))
  end

  test "display_member_city_with_zip omits missing zip" do
    assert_equal "Lausanne", display_member_city_with_zip(member_address("Lausanne", nil))
  end

  test "display_member_city_with_zip shows zip when city is missing" do
    assert_equal "1000", display_member_city_with_zip(member_address(nil, "1000"))
  end

  test "display_member_city_with_zip renders empty placeholder when city and zip are missing" do
    html = display_member_city_with_zip(member_address("", nil)).to_s

    assert_includes html, "attributes-table-empty-value"
    assert_includes html, I18n.t("active_admin.empty")
  end

  test "short_price uses two decimals for whole amounts" do
    assert_equal "30.00", short_price(30)
    assert_equal "30.00", short_price(30.0)
    assert_equal "45.50", short_price(45.5)
    assert_equal "~12.35", short_price(12.345)
  end

  test "basket_complement_details tooltips included-absence prorata" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:mondays)
    cycle.update!(absences_included_annually: 2)
    complement = basket_complements(:bread)
    complement.delivery_ids = cycle.current_and_future_delivery_ids.take(5)
    @depots_delivery_cycles = [ cycle ]

    html = basket_complement_details(complement).to_s
    hint = I18n.t("helpers.basket_complement_absences_included")

    assert_includes html, "title=\"#{hint}\""
    assert_not_includes basket_complement_details(complement, force_default: true).to_s, hint
  end

  test "link_with_session renders unavailable actor as missing data" do
    html = link_with_session(Unavailable.instance, nil).to_s

    assert_includes html, Unavailable.instance.name
    assert_includes html, "muted-data"
    assert_not_includes html, "href"
  end

  private

  def member_address(city, zip)
    Struct.new(:city, :zip).new(city, zip)
  end

  def insert_shop_order(member, created_at)
    Shop::Order.insert_all!([ {
      member_id: member.id,
      delivery_id: deliveries(:monday_2).id,
      delivery_type: "Delivery",
      state: "pending",
      amount: 0,
      created_at: created_at,
      updated_at: created_at
    } ])
  end

  def admin_index_mail_deliveries(newsletter)
    MailDelivery
      .newsletter_id_eq(newsletter.id)
      .includes(:member, :emails)
      .left_joins(:member)
      .merge(Member.order_by_name)
      .order(created_at: :desc)
      .limit(50)
  end

  def insert_newsletter_delivery(newsletter, member, emails: [])
    insert_newsletter_deliveries(newsletter, [ member ], 1, emails: emails)
  end

  def insert_newsletter_deliveries(newsletter, members, count, start_at: Time.current, emails: %w[one@doe.com two@doe.com])
    now = start_at
    rows = members.flat_map { |member|
      count.times.map { |index|
        {
          mailable_type: "Newsletter",
          mailable_ids: [ newsletter.id ],
          action: "newsletter",
          member_id: member.id,
          subject: "Extra #{member.id} #{index}",
          state: "delivered",
          created_at: now - index.minutes,
          updated_at: now - index.minutes
        }
      }
    }
    existing_ids = MailDelivery.newsletter_id_eq(newsletter.id).pluck(:id)
    MailDelivery.insert_all!(rows)
    return if emails.empty?

    deliveries = MailDelivery.newsletter_id_eq(newsletter.id).where(member: members).where.not(id: existing_ids)
    MailDelivery::Email.insert_all!(deliveries.flat_map { |delivery|
      emails.map { |email|
        {
          mail_delivery_id: delivery.id,
          email: "#{delivery.id}-#{email}",
          state: "delivered",
          created_at: delivery.created_at,
          updated_at: delivery.updated_at,
          email_suppression_ids: [],
          email_suppression_reasons: []
        }
      }
    })
  end

  def collect_sql_queries
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql]
      queries << sql unless payload[:name] == "SCHEMA" || sql.match?(/\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  def member_id_distinct_plucks(queries)
    queries.select { |sql|
      sql.match?(/DISTINCT/i) && sql.match?(/["`]mail_deliveries["`]\.["`]member_id["`]/i)
    }
  end

  def assert_lean_member_id_pluck(sql)
    assert_no_match(/JOIN ["`]members["`]/i, sql)
    assert_no_match(/members_mail_deliveries/i, sql)
    assert_no_match(/mail_delivery_emails/i, sql)
    assert_no_match(/ORDER BY ["`]mail_deliveries["`]\.["`]created_at["`]/i, sql)
  end
end
