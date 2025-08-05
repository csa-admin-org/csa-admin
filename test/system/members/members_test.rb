# frozen_string_literal: true

require "application_system_test_case"

class Members::MembersTest < ApplicationSystemTestCase
  setup { travel_to "2024-01-01" }

  test "registration" do
    org(allow_alternative_depots: true)
    admins(:super).update(notifications: [ "new_registration" ])

    visit "/new"

    fill_in "Name and surname", with: "Ryan and Sophie Doe"
    fill_in "Address", with: "Nowhere street 2"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    fill_in "Email(s)", with: "ryan@doe.com, sophie@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42, 077 143 44 44"

    assert_text "Basket size"
    assert_text "Large basketCHF 300-600 (30.- x 10-20 deliveries), 3 half-days"
    assert_text "Medium basketCHF 200-400 (20.- x 10-20 deliveries), 2 half-days"
    assert_text "Small basketCHF 100-200 (10.- x 10-20 deliveries), 2 half-days"
    assert_text "Supporting memberAnnual fee only"
    choose "Large basket"

    assert_text "Basket complements"
    assert_text "BreadCHF 40.00 (4.- x 0-10 deliveries)"
    assert_text "EggsCHF 60.00 (6.- x 0-10 deliveries)"
    fill_in "Bread", with: "1"
    fill_in "Eggs", with: "2"

    assert_text "Support"
    assert_text "Base price"
    assert_text "+ 1.-/basketCHF 10-20"
    assert_text "+ 2.-/basketCHF 20-40"
    assert_text "+ 3.-/basketCHF 30-60"
    choose "+ 1.-/basket"

    assert_text "Depot"
    assert_text "Our farm42 Nowhere, 1234 Unknown"
    assert_text "BakeryCHF 40-80 (4.- x 10-20 deliveries)"
    assert_text "HomeCHF 90-180 (9.- x 10-20 deliveries)"
    choose "Bakery"

    assert_text "Alternative depot(s)"
    check "Home"

    assert_text "Deliveries"
    assert_text "All20 deliveries"
    assert_text "Mondays10 deliveries"
    assert_text "Thursdays10 deliveries"
    choose "Thursdays"

    assert_text "Billing"
    assert_text "Annual"
    assert_text "Semi-annual"
    assert_text "Four-monthly"
    assert_text "Quarterly"
    assert_text "Monthly"
    choose "Quarterly"

    fill_in "Profession / Skills", with: "Software developer"
    fill_in "How did you hear about us?", with: "Friends"
    fill_in "Note", with: "Keep up the good work!"
    check "I have read and agree to the rules."

    click_on "Submit"

    assert_text "Thank you for your registration!"
    assert_text "Your registration will be confirmed in the coming days. We are at your disposal for any questions."

    member = Member.last
    assert_equal "pending", member.state
    assert_equal "Ryan and Sophie Doe", member.name
    assert_equal "Nowhere street 2", member.address
    assert_equal "2042", member.zip
    assert_equal "CH", member.country_code
    assert_equal [ "ryan@doe.com", "sophie@doe.com" ], member.emails_array
    assert_equal [ "+41771424242", "+41771434444" ], member.phones_array
    assert_equal "en", member.language
    assert_equal "Software developer", member.profession
    assert_equal "Friends", member.come_from
    assert_equal "Keep up the good work!", member.note
    assert_equal large_id, member.waiting_basket_size_id
    assert_equal 1, member.waiting_basket_price_extra
    assert_equal bakery_id, member.waiting_depot_id
    assert_equal [ home_id ], member.waiting_alternative_depot_ids
    assert_equal [ eggs_id, bread_id ], member.waiting_basket_complement_ids
    assert_equal [ 1, 2 ], member.members_basket_complements.map(&:quantity)
    assert_equal thursdays_id, member.waiting_delivery_cycle_id
    assert_equal 4, member.waiting_billing_year_division
    assert_equal 30, member.annual_fee

    assert_difference -> { ActionMailer::Base.deliveries.size } do
      perform_enqueued_jobs
    end
    mail = AdminMailer.deliveries.last
    assert_equal "New registration", mail.subject
    assert_equal [ admins(:super).email ], mail.to
    assert_includes mail.body.encoded, "Ryan and Sophie Doe"
  end

  test "put back inactive existing member to waiting list" do
    admins(:super).update(notifications: [ "new_registration" ])
    member = members(:mary)

    visit "/new"

    fill_in "Name", with: "Mary Doe"
    fill_in "Address", with: "Nowhere Street 47"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    select "Switzerland", from: "Country"

    fill_in "Email(s)", with: "mary@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42"

    choose "Small basket"
    choose "Base price"
    choose "Our farm"
    choose "Mondays"
    choose "Annual"
    fill_in "Note", with: "I'm back!"
    check "I have read and agree to the rules."

    assert_changes -> { member.reload.state }, from: "inactive", to: "waiting" do
      click_button "Submit"
    end

    assert_text "Thank you for your registration!"

    assert_equal "Mary Doe", member.name
    assert_equal "Nowhere Street 47", member.address
    assert_equal small_id, member.waiting_basket_size_id
    assert_equal 0, member.waiting_basket_price_extra
    assert_equal farm_id, member.waiting_depot_id
    assert_equal mondays_id, member.waiting_delivery_cycle_id
    assert_equal 1, member.waiting_billing_year_division
    assert_equal 30, member.annual_fee

    assert_difference -> { ActionMailer::Base.deliveries.size } do
      perform_enqueued_jobs
    end
    mail = AdminMailer.deliveries.last
    assert_equal "New re-registration", mail.subject
    assert_equal [ admins(:super).email ], mail.to
    assert_includes mail.body.encoded, "An existing member, Mary Doe, has re-registered!"
  end

  test "does not allow existing active member" do
    visit "/new"

    fill_in "Name and surname", with: "John Doe"
    fill_in "Address", with: "Nowhere street 2"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    fill_in "Email(s)", with: "john@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42"

    choose "Supporting member"
    check "I have read and agree to the rules."

    assert_no_difference "Member.count" do
      click_button "Submit"
    end

    assert_text "An active account already exists for this email address!"
  end

  test "creates a new member with custom activity participations" do
    org(activity_participations_form_min: 0)
    basket_complements(:eggs).update!(activity_participations_demanded_annually: 1)

    visit "/new"

    fill_in "Name and surname", with: "Ryan Doe"
    fill_in "Address", with: "Nowhere street 2"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    fill_in "Email(s)", with: "ryan@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42"

    choose "Large basket"
    fill_in "Eggs", with: "1"
    fill_in "½ Days", with: 1
    choose "Base price"
    choose "Our farm"
    choose "Mondays"
    choose "Annual"
    fill_in "Note", with: "I'm back!"
    check "I have read and agree to the rules."

    click_button "Submit"

    assert_text "Thank you for your registration!"

    member = Member.last
    assert_equal "Ryan Doe", member.name
    assert_equal 1, member.waiting_activity_participations_demanded_annually
  end

  test "delivery cycles with absenses included" do
    delivery_cycles(:all).update(absences_included_annually: 2)
    delivery_cycles(:mondays).update(absences_included_annually: 1)
    delivery_cycles(:thursdays).update(absences_included_annually: 1)

    visit "/new"

    assert_text "Large basketCHF 270-540 (30.- x 9-18 deliveries), 3 half-days"
    assert_text "Medium basketCHF 180-360 (20.- x 9-18 deliveries), 2 half-days"
    assert_text "Small basketCHF 90-180 (10.- x 9-18 deliveries), 2 half-days"

    assert_text "BreadCHF 36.00 (4.- x 0-9 deliveries)"
    assert_text "EggsCHF 54.00 (6.- x 0-9 deliveries)"

    assert_text "+ 1.-/basketCHF 9-18"
    assert_text "+ 2.-/basketCHF 18-36"
    assert_text "+ 3.-/basketCHF 27-54"

    assert_text "Our farm42 Nowhere, 1234 Unknown"
    assert_text "BakeryCHF 36-72 (4.- x 9-18 deliveries)"
    assert_text "HomeCHF 81-162 (9.- x 9-18 deliveries)"
  end

  test "shop-only member form mode" do
    travel_to "2024-01-01"
    org(member_form_mode: "shop", terms_of_service_urls: {})

    visit "/new"

    assert_no_text "Membership"
    assert_text "Farm shop"
    assert_text "Please choose a depot for your orders."

    fill_in "Name and surname", with: "Ryan Doe"
    fill_in "Address", with: "Nowhere street 2"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    fill_in "Email(s)", with: "ryan@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42"

    assert_text "Our farm42 Nowhere, 1234 Unknown"
    assert_text "Bakery"
    assert_text "Home"
    choose "Bakery"

    click_button "Submit"

    assert_text "Thank you for your registration!"

    member = Member.last
    assert_equal "pending", member.state
    assert_equal "Ryan Doe", member.name
    assert_nil member.waiting_basket_size
    assert_nil member.waiting_depot
    assert_equal bakery_id, member.shop_depot_id
    assert_nil member.waiting_billing_year_division
  end

  test "support member (annual fee)" do
    org(annual_fee_support_member_only: true)

    visit "/new"

    assert_text "Each supporting member (without subscription) pays an annual fee of CHF 30."

    fill_in "Name and surname", with: "Ryan Doe"
    fill_in "Address", with: "Nowhere street 2"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    fill_in "Email(s)", with: "ryan@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42"

    choose "Supporting member"
    check "I have read and agree to the rules."

    click_button "Submit"

    assert_text "Thank you for your registration!"

    member = Member.last
    assert_equal "pending", member.state
    assert_equal "Ryan Doe", member.name
    assert_nil member.waiting_basket_size
    assert_nil member.waiting_depot
    assert_equal 30, member.annual_fee
    assert_nil member.waiting_billing_year_division
  end

  test "creates a new support member (custom annual fee)" do
    org(annual_fee_member_form: true)

    visit "/new"

    assert_text "Each member also pays an annual fee of CHF 30 in addition to the membership to the basket."

    fill_in "Name and surname", with: "Ryan Doe"
    fill_in "Address", with: "Nowhere street 2"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    fill_in "Email(s)", with: "ryan@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42"

    choose "Supporting member"
    fill_in "Annual fee", with: "50"
    check "I have read and agree to the rules."

    click_button "Submit"

    assert_text "Thank you for your registration!"

    member = Member.last
    assert_equal "pending", member.state
    assert_equal "Ryan Doe", member.name
    assert_equal 50, member.annual_fee
  end

  test "put back inactive existing member to support" do
    admins(:super).update(notifications: [ "new_registration" ])
    member = members(:mary)

    visit "/new"

    fill_in "Name", with: "Mary Doe"
    fill_in "Address", with: "Nowhere Street 47"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    select "Switzerland", from: "Country"

    fill_in "Email(s)", with: "mary@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42"

    choose "Supporting member"
    check "I have read and agree to the rules."

    assert_changes -> { member.reload.state }, from: "inactive", to: "support" do
      click_button "Submit"
    end

    assert_text "Thank you for your registration!"

    assert_equal "Mary Doe", member.name
    assert_equal 30, member.annual_fee

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      perform_enqueued_jobs
    end
  end

  test "support member (share)" do
    org(annual_fee: nil, share_price: 250, shares_number: 2)

    visit "/new"

    assert_text "Each member joins the cooperative and must acquire one or more shares (CHF 250/share)."

    fill_in "Name and surname", with: "Ryan Doe"
    fill_in "Address", with: "Nowhere street 2"
    fill_in "ZIP", with: "2042"
    fill_in "City", with: "Moon City"
    fill_in "Email(s)", with: "ryan@doe.com"
    fill_in "Phone(s)", with: "077 142 42 42"

    assert_no_text "Supporting memberAnnual fee only"
    assert_text "Supporting memberCooperative share only"
    choose "Supporting member"
    fill_in "Share certificates", with: "3"

    check "I have read and agree to the rules."
    click_button "Submit"

    assert_text "Thank you for your registration!"

    member = Member.last
    assert_equal "pending", member.state
    assert_equal "Ryan Doe", member.name
    assert_nil member.waiting_basket_size
    assert_nil member.waiting_depot
    assert_nil member.annual_fee
    assert_equal 3, member.desired_shares_number
    assert_nil member.waiting_billing_year_division
  end

  test "hides waiting_billing_year_division when only one is configured" do
    org(billing_year_divisions: [ 12 ])

    visit "/new"

    assert_no_text "Payment interval"
    assert_no_selector "#member_waiting_billing_year_division_input"
  end

  test "shows only membership extra text" do
    default_text = "Each member also pays an annual fee"
    extra_text = "Special rules"
    Current.org.update!(member_form_extra_text: extra_text)

    visit "/new"
    assert_text default_text
    assert_text extra_text

    org(member_form_extra_text_only: true)
    visit "/new"

    assert_no_text default_text
    assert_text extra_text
  end

  test "orders depots by form priority" do
    depots(:farm).update!(member_order_priority: 0)
    depots(:home).update!(member_order_priority: 1)
    depots(:bakery).update!(member_order_priority: 2)

    visit "/new"

    depot_ids = all(".member_waiting_depot_id span input").map(&:value).map(&:to_i)
    assert_equal [ farm_id, home_id, bakery_id ], depot_ids
  end

  test "different billing address" do
    org(terms_of_service_urls: {})

    visit "/new?different_billing_info=true"

    within "[aria-label='Contact']" do
      fill_in "Name and surname", with: "Ryan Doe"
      fill_in "Address", with: "Nowhere street 2"
      fill_in "ZIP", with: "2042"
      fill_in "City", with: "Moon City"
      fill_in "Email(s)", with: "ryan@doe.com"
      fill_in "Phone(s)", with: "077 142 42 42, 077 143 44 44"
    end

    choose "Supporting member"

    within "[aria-label='Billing']" do
      assert find("#member_different_billing_info").checked?
      fill_in "Name (billing)", with: "Ryan Corp."
      fill_in "Address (billing)", with: "Corp street 2"
      fill_in "ZIP", with: "4200"
      fill_in "City", with: "Corp City"
    end

    click_button "Submit"
    assert_text "Thank you for your registration!"

    member = Member.last
    assert_equal "pending", member.state
    assert_equal "Ryan Doe", member.name
    assert_equal "Ryan Corp.", member.billing_name
    assert_equal "Corp street 2", member.billing_address
    assert_equal "4200", member.billing_zip
    assert_equal "Corp City", member.billing_city
    assert member.different_billing_info
  end

  test "notifies spam detection" do
    org(terms_of_service_urls: {})

    visit "/new"

    fill_in "Name and surname", with: "Р РѕСЃСЃРёСЏ"
    fill_in "Address", with: "Р РѕСЃСЃРёСЏ"
    fill_in "ZIP", with: "999999"
    fill_in "City", with: "Р РѕСЃСЃРёСЏ"
    fill_in "Email(s)", with: "john@doe.com"
    choose "Supporting member"

    assert_no_difference -> { Member.count } do
      click_button "Submit"
    end

    assert_text "Thank you for your registration!"
  end

  test "without annual fee or organization shares" do
    org(annual_fee: nil, share_price: nil)

    visit "/new"

    assert_no_text "Supporting member"
  end

  test "with different form modes" do
    org(member_profession_form_mode: "hidden", member_come_from_form_mode: "required")

    visit "/new"

    assert_no_text "Profession / Skills"
    assert_text "How did you hear about us? *"

    click_button "Submit"

    assert_text "How did you hear about us? * can't be blank"
  end

  test "pre-populate basket size and complements" do
    visit "/new?basket_size_id=#{small_id}&basket_complements[#{eggs_id}]=1&basket_complements[#{bread_id}]=2"

    assert find_field("Small basket").checked?
    assert_equal "1", find_field("Eggs").value
    assert_equal "2", find_field("Bread").value
  end

  # ==================== Member page ==========================

  test "redirects to deliveries with next basket" do
    login(members(:john))

    assert_equal "/deliveries", current_path
    assert_selector "h1", text: "Deliveries"

    assert_equal [
      "Deliveries\n⤷ 1 April 2024",
      "Shop\n⤷ 1 April 2024", "⤷ 5 April 2024",
      "Membership\n⤷ Current",
      "Contact sharing\n⤷ Our farm",
      "½ Days\n⤷ 2 of 2 requested",
      "Billing\n⤷ View history",
      "Absences\n⤷ Let us know!",
      "Newsletters\n⤷ 1 April 2024"
    ], menu_nav
  end

  test "redirects to activity_participations with no commitment" do
    login(members(:martha))

    assert_equal "/activity_participations", current_path
    assert_selector "h1", text: "½ Days"
    assert_includes menu_nav,  "½ Days\n⤷ No commitment"
  end

  test "redirects to shop" do
    member = members(:martha)
    member.update!(shop_depot_id: farm_id)
    deliveries(:monday_1).update!(shop_open: true)
    login(member)

    assert_equal "/shop", current_path
    assert_selector "h1", text: "Shop"
    assert_text "1 April 2024"
    assert_contains menu_nav, [
      "Shop\n⤷ 1 April 2024",
      "⤷ 5 April 2024"
    ]
  end

  test "redirects to billing without activity feature" do
    org(features: [])
    login(members(:martha))

    assert_equal "/billing", current_path
    assert_selector "h1", text: "Billing"
    assert_equal [ "Billing\n⤷ 1 open invoice" ], menu_nav
  end

  test "redirects inactive user to billing" do
    login(members(:mary))

    assert_equal "/billing", current_path
    assert_selector "h1", text: "Billing"
    assert_equal [ "Billing\n⤷ View history" ], menu_nav
  end
end
