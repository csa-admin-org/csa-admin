# frozen_string_literal: true

require "application_system_test_case"

class Members::AccountsTest < ApplicationSystemTestCase
  test "shows current member data" do
    org(languages: %w[en fr])
    member = members(:john)
    member.update!(phones: "+41 79 123 45 67, +33 6 12 34 56 78")
    login(member)

    click_on "John Doe"

    assert_text member.id
    assert_text "John Doe"
    assert_text "John Doe Nowhere 421234 City"
    assert_text "john@doe.com"
    assert_text "079 123 45 67, +33 6 12 34 56 78"
    assert_text "English"
  end

  test "edits current member data" do
    travel_to "2024-01-01"
    member = members(:john)
    login(member)

    click_on "John Doe"
    click_on "Edit account"

    fill_in "Name", with: "John & Jane Doe"
    fill_in "member_zip", with: "12345"
    fill_in "member_city", with: "Villar"
    select "Germany", from: "member_country_code"

    click_button "Submit"

    assert_text "John & Jane Doe"
    assert_text "Nowhere 4212345 Villar"

    assert_equal({
      "zip" => [ "1234", "12345" ],
      "city" => [ "City", "Villar" ],
      "country_code" => [ "CH", "DE" ],
      "name" => [ "John Doe", "John & Jane Doe" ]
    }, member.audits.last.audited_changes)
  end

  test "edit shop depot" do
    member = members(:mary)
    member.update!(shop_depot_id: farm_id)
    login(member)

    click_on "Mary"
    assert_text "Our farm"

    click_on "Edit account"
    choose "Bakery"

    assert_changes -> { member.reload.shop_depot_id }, to: bakery_id do
      click_button "Submit"
    end

    assert_text "Bakery"
  end

  test "edit different billing address" do
    member = members(:john)
    member.update!(
      billing_name: "Acme Doe",
      billing_street: "Acme Street 42",
      billing_city: "Acme City",
      billing_zip: "1234")
    login(member)

    click_on "John Doe"

    assert_text "Acme Doe"
    assert_text "Acme Street 42"
    assert_text "Acme City"
    assert_text "1234"

    click_on "Edit account"

    within "[aria-label='Billing']" do
      assert find("#member_different_billing_info").checked?
      fill_in "Name", with: "Acme Corp."
    end

    click_button "Submit"
    assert_text "Acme Corp."
  end
end
