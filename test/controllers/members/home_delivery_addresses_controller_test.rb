# frozen_string_literal: true

require "test_helper"

class Members::HomeDeliveryAddressesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    travel_to "2024-04-01"
    org(basket_update_limit_in_days: 0)
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "edit disables address fields when a frozen delivery remains" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    HomeDeliveryAddressDelivery.insert_all!([
      {
        home_delivery_address_id: overlay.id,
        delivery_id: deliveries(:monday_past_1).id,
        member_id: members(:bob).id,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
    login(members(:bob))

    get edit_members_home_delivery_address_path(overlay)

    assert_response :success
    assert_select "#home_delivery_address_name[disabled]"
    assert_select "#home_delivery_address_street[disabled]"
  end

  test "new page pre-checks the basket delivery" do
    basket = baskets(:bob_1)
    login(members(:bob))

    get new_members_basket_home_delivery_address_path(basket)

    assert_response :success
    assert_select "input[name='home_delivery_address[delivery_ids][]'][value=?][checked]",
      basket.delivery_id.to_s
  end

  test "new redirects for signature depot baskets" do
    basket = memberships(:john).baskets.first
    login(members(:john))

    get new_members_basket_home_delivery_address_path(basket)

    assert_redirected_to members_deliveries_path
  end

  test "creates overlay and redirects to deliveries" do
    basket = baskets(:bob_1)
    login(members(:bob))

    assert_difference -> { HomeDeliveryAddress.count }, 1 do
      post members_home_delivery_addresses_path, params: {
        home_delivery_address: {
          name: "Valentine Schneider",
          street: "Chantemerle 16",
          zip: "2000",
          city: "Neuchatel",
          delivery_ids: [ basket.delivery_id ]
        }
      }
    end

    assert_redirected_to members_deliveries_path
    overlay = HomeDeliveryAddress.last
    assert_equal members(:bob).id, overlay.member_id
    assert_equal [ basket.delivery_id ], overlay.delivery_ids
  end

  test "cannot create without a delivery" do
    login(members(:bob))

    assert_no_difference -> { HomeDeliveryAddress.count } do
      post members_home_delivery_addresses_path, params: {
        home_delivery_address: {
          name: "Valentine Schneider",
          street: "Chantemerle 16",
          zip: "2000",
          city: "Neuchatel",
          delivery_ids: [ "" ]
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create redirects when all deliveries are past the member deadline" do
    basket = baskets(:bob_1)
    org(basket_update_limit_in_days: 30)
    login(members(:bob))

    assert_no_difference -> { HomeDeliveryAddress.count } do
      post members_home_delivery_addresses_path, params: {
        home_delivery_address: {
          name: "Valentine Schneider",
          street: "Chantemerle 16",
          zip: "2000",
          city: "Neuchatel",
          delivery_ids: [ basket.delivery_id ]
        }
      }
    end

    assert_redirected_to members_deliveries_path
  end

  test "cannot create for another member basket" do
    basket = baskets(:bob_1)
    login(members(:john))

    get new_members_basket_home_delivery_address_path(basket)

    assert_response :not_found
  end

  test "edit and destroy own overlay" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    login(members(:bob))

    get edit_members_home_delivery_address_path(overlay)
    assert_response :success

    patch members_home_delivery_address_path(overlay), params: {
      home_delivery_address: {
        name: "Alice Doe",
        street: overlay.street,
        zip: overlay.zip,
        city: overlay.city,
        delivery_ids: overlay.delivery_ids
      }
    }
    assert_redirected_to members_deliveries_path
    assert_equal "Alice Doe", overlay.reload.name

    assert_difference -> { HomeDeliveryAddress.count }, -1 do
      delete members_home_delivery_address_path(overlay)
    end
    assert_redirected_to members_deliveries_path
  end

  test "cannot edit overlay past the member deadline" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    org(basket_update_limit_in_days: 30)
    login(members(:bob))

    get edit_members_home_delivery_address_path(overlay)

    assert_redirected_to members_deliveries_path

    patch members_home_delivery_address_path(overlay), params: {
      home_delivery_address: {
        name: "Alice Doe",
        street: overlay.street,
        zip: overlay.zip,
        city: overlay.city,
        delivery_ids: overlay.delivery_ids
      }
    }
    assert_redirected_to members_deliveries_path
    assert_equal "Valentine Schneider", overlay.reload.name
  end

  test "update keeps frozen deliveries omitted from params" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    HomeDeliveryAddressDelivery.insert_all!([
      {
        home_delivery_address_id: overlay.id,
        delivery_id: deliveries(:monday_past_1).id,
        member_id: members(:bob).id,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
    login(members(:bob))

    patch members_home_delivery_address_path(overlay), params: {
      home_delivery_address: {
        name: overlay.name,
        street: overlay.street,
        zip: overlay.zip,
        city: overlay.city,
        delivery_ids: [ deliveries(:monday_1).id ]
      }
    }

    overlay.reload
    assert_equal "Valentine Schneider", overlay.name
    assert_includes overlay.delivery_ids, deliveries(:monday_past_1).id
    assert_includes overlay.delivery_ids, deliveries(:monday_1).id
  end

  test "cannot change address while frozen deliveries remain" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    HomeDeliveryAddressDelivery.insert_all!([
      {
        home_delivery_address_id: overlay.id,
        delivery_id: deliveries(:monday_past_1).id,
        member_id: members(:bob).id,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
    login(members(:bob))

    patch members_home_delivery_address_path(overlay), params: {
      home_delivery_address: {
        name: "Alice Doe",
        street: overlay.street,
        zip: overlay.zip,
        city: overlay.city,
        delivery_ids: overlay.delivery_ids
      }
    }

    assert_response :unprocessable_entity
    assert_equal "Valentine Schneider", overlay.reload.name
  end

  test "cannot destroy overlay that still has frozen deliveries" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    HomeDeliveryAddressDelivery.insert_all!([
      {
        home_delivery_address_id: overlay.id,
        delivery_id: deliveries(:monday_past_1).id,
        member_id: members(:bob).id,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
    login(members(:bob))

    assert_no_difference -> { HomeDeliveryAddress.count } do
      delete members_home_delivery_address_path(overlay)
    end
    assert_redirected_to members_deliveries_path
    assert_includes overlay.reload.delivery_ids, deliveries(:monday_past_1).id
  end

  test "cannot edit another member overlay" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    login(members(:john))

    get edit_members_home_delivery_address_path(overlay)
    assert_response :not_found
  end
end
