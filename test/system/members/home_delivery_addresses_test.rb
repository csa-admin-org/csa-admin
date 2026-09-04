# frozen_string_literal: true

require "application_system_test_case"

class Members::HomeDeliveryAddressesTest < ApplicationSystemTestCase
  setup { travel_to "2024-04-01" }

  test "titles the next section Today when the delivery is today" do
    org(basket_update_limit_in_days: 0)
    login(members(:bob))

    visit "/deliveries"

    assert_text "Today"
    assert_no_text "Next"
  end

  test "shows deliver elsewhere once on the first coming home-delivery basket" do
    org(basket_update_limit_in_days: 0)
    extra = create_bob_coming_home_basket

    login(members(:bob))
    visit "/deliveries"

    assert_selector :link, "Deliver elsewhere", count: 1
    within "#basket_#{baskets(:bob_1).id}" do
      assert_no_text "Deliver elsewhere"
    end
    within "#basket_#{extra.id}" do
      assert_text "Deliver elsewhere"
    end
  end

  test "creates and shows a temporary address on the basket card" do
    org(basket_update_limit_in_days: 0)
    extra = create_bob_coming_home_basket
    login(members(:bob))

    visit "/deliveries"
    within "#basket_#{extra.id}" do
      click_on "Deliver elsewhere"
    end

    assert_text "dropped at someone else's"
    assert_link "your address", href: members_account_path
    fill_in "Person at the door", with: "Valentine Schneider"
    fill_in "Street", with: "Chantemerle 16"
    fill_in "ZIP", with: "2000"
    fill_in "City", with: "Neuchatel"
    click_on "Confirm"

    assert_equal "/deliveries", current_path
    within "#basket_#{extra.id}" do
      assert_text "Valentine Schneider"
      assert_no_text "Deliver elsewhere"
    end
  end

  test "does not offer deliver elsewhere on a signature depot" do
    login(members(:john))

    visit "/deliveries"

    assert_no_text "Deliver elsewhere"
  end

  private

  def create_bob_coming_home_basket
    memberships(:bob).update_column(:ended_on, Date.new(2024, 4, 15))
    Basket.create!(
      membership: memberships(:bob),
      delivery: deliveries(:monday_2),
      basket_size: basket_sizes(:small),
      basket_size_price: 10,
      depot: depots(:home),
      depot_price: 9,
      quantity: 1)
  end
end
