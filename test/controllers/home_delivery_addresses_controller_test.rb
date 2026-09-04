# frozen_string_literal: true

require "test_helper"

class HomeDeliveryAddressesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    travel_to "2024-04-01"
    login admins(:super)
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "member show offers a temporary change under the address" do
    get member_path(members(:bob))

    assert_response :success
    assert_select "[data-row=address] a.btn[href=?]", new_home_delivery_address_path(member_id: members(:bob).id)
    assert_select ".attributes-table th", text: HomeDeliveryAddress.model_name.human, count: 0
    assert_select "h3", text: HomeDeliveryAddress.model_name.human(count: 2), count: 0
  end

  test "member show lists overlays on the next basket and has no overlay panel" do
    current = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    past = HomeDeliveryAddress.new(
      member: members(:bob),
      name: "Alice Doe",
      street: "Elsewhere 1",
      zip: "2000",
      city: "Neuchatel")
    past.save(validate: false)
    HomeDeliveryAddressDelivery.insert_all!([
      {
        home_delivery_address_id: past.id,
        delivery_id: deliveries(:monday_past_1).id,
        member_id: members(:bob).id,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])

    get member_path(members(:bob))

    assert_response :success
    assert_select "h3", text: HomeDeliveryAddress.model_name.human(count: 2), count: 0
    assert_select "a[href=?]", edit_home_delivery_address_path(current), text: /Valentine Schneider/
    assert_select "a[href=?]", edit_home_delivery_address_path(current), text: /Chantemerle 16/
    assert_select ".is-italic.is-faint a[href=?]", edit_home_delivery_address_path(past), text: /Alice Doe/
    assert_select ".is-italic.is-faint a[href=?]", edit_home_delivery_address_path(past), text: /Elsewhere 1/
    assert_select "[data-row=address] a.btn[href=?]", new_home_delivery_address_path(member_id: members(:bob).id), false
  end

  test "member contact lists every coming overlay" do
    first = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    second = HomeDeliveryAddress.new(
      member: members(:bob),
      name: "Alice Doe",
      street: "Elsewhere 1",
      zip: "2000",
      city: "Neuchatel")
    second.save(validate: false)
    HomeDeliveryAddressDelivery.insert_all!([
      {
        home_delivery_address_id: second.id,
        delivery_id: deliveries(:monday_2).id,
        member_id: members(:bob).id,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])

    get member_path(members(:bob))

    assert_response :success
    assert_select "a[href=?]", edit_home_delivery_address_path(first)
    assert_select "a[href=?]", edit_home_delivery_address_path(second), text: /Elsewhere 1/
    assert_select ".is-italic.is-faint a[href=?]", edit_home_delivery_address_path(second), text: /Elsewhere 1/, count: 0
  end

  test "member show does not link overlay edit without write" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    login admins(:external)

    get member_path(members(:bob))

    assert_response :success
    assert_select "a[href=?]", edit_home_delivery_address_path(overlay), count: 0
    assert_select ".attributes-table", text: /Valentine Schneider/
  end

  test "member edit points to a temporary address from the contact fieldset" do
    get edit_member_path(members(:bob))

    assert_response :success
    assert_select ".admin-info-pane a.btn[href=?]", new_home_delivery_address_path(member_id: members(:bob).id)
    assert_select "#member_delivery_note_input .inline-hints",
      text: I18n.t("formtastic.hints.member.delivery_note_home")
  end

  test "member show does not offer overlay for signature depot members" do
    get member_path(members(:john))

    assert_response :success
    assert_select "a[href=?]", new_home_delivery_address_path(member_id: members(:john).id), false
  end

  test "new page breadcrumbs include the member" do
    get new_home_delivery_address_path(member_id: members(:bob).id)

    assert_response :success
    assert_select ".admin-breadcrumb-list a[href=?]", member_path(members(:bob)), text: members(:bob).name
    assert_select "h2", text: I18n.t("active_admin.resources.home_delivery_address.new_model")
  end

  test "create without deliveries saves an unused overlay" do
    assert_difference -> { HomeDeliveryAddress.count }, 1 do
      post home_delivery_addresses_path, params: {
        home_delivery_address: {
          member_id: members(:bob).id,
          name: "Valentine Schneider",
          street: "Chantemerle 16",
          zip: "2000",
          city: "Neuchatel",
          delivery_ids: [ "" ]
        }
      }
    end

    overlay = HomeDeliveryAddress.last
    assert_redirected_to member_path(members(:bob))
    assert_equal "Valentine Schneider", overlay.name
    assert_empty overlay.delivery_ids
  end

  test "creates overlay from member and redirects to member" do
    assert_difference -> { HomeDeliveryAddress.count }, 1 do
      post home_delivery_addresses_path, params: {
        home_delivery_address: {
          member_id: members(:bob).id,
          name: "Valentine Schneider",
          street: "Chantemerle 16",
          zip: "2000",
          city: "Neuchatel",
          delivery_ids: [ deliveries(:monday_1).id ]
        }
      }
    end

    overlay = HomeDeliveryAddress.last
    assert_redirected_to member_path(members(:bob))
    assert_equal "Valentine Schneider", overlay.name
    assert_equal [ deliveries(:monday_1).id ], overlay.delivery_ids
    assert_equal members(:bob).id, overlay.home_delivery_address_deliveries.first.member_id
  end

  test "update keeps past deliveries omitted from params" do
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

    patch home_delivery_address_path(overlay), params: {
      home_delivery_address: {
        name: "Alice Doe",
        street: overlay.street,
        zip: overlay.zip,
        city: overlay.city,
        delivery_ids: [ deliveries(:monday_1).id ]
      }
    }

    overlay.reload
    assert_redirected_to member_path(members(:bob))
    assert_equal "Alice Doe", overlay.name
    assert_includes overlay.delivery_ids, deliveries(:monday_past_1).id
  end

  test "update can drop coming deliveries" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])

    patch home_delivery_address_path(overlay), params: {
      home_delivery_address: {
        name: overlay.name,
        street: overlay.street,
        zip: overlay.zip,
        city: overlay.city,
        delivery_ids: [ "" ]
      }
    }

    overlay.reload
    assert_redirected_to member_path(members(:bob))
    assert_empty overlay.delivery_ids
  end

  test "edit page has a new button, a delete button, and no show page" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])

    get edit_home_delivery_address_path(overlay)
    assert_response :success
    assert_select ".action-item-button[href=?]", new_home_delivery_address_path(member_id: members(:bob).id)
    assert_select ".action-item-button.destructive"
    assert_select ".admin-breadcrumb-list a[href=?]", member_path(members(:bob)), text: members(:bob).name
    assert_select ".admin-breadcrumb-item", text: HomeDeliveryAddress.model_name.human
    assert_select ".admin-breadcrumb-list a", text: HomeDeliveryAddress.model_name.human, count: 0

    get home_delivery_address_path(overlay)
    assert_response :not_found
  end

  test "new page disables deliveries already used by another overlay" do
    HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])

    get new_home_delivery_address_path(member_id: members(:bob).id)

    assert_response :success
    assert_select "li.check_boxes input[type=checkbox][value=?][disabled]", deliveries(:monday_1).id.to_s
  end

  test "home-delivery depot next list links the overlay next to the member" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])

    get depot_path(depots(:home), delivery_id: deliveries(:monday_1).id)

    assert_response :success
    assert_select "a", text: members(:bob).name
    assert_select "a[href=?]", edit_home_delivery_address_path(overlay) do
      assert_select ".status-tag", text: /#{Regexp.escape(HomeDeliveryAddress.model_name.human)}/i
    end
  end

  test "signature depot next list has no overlay link" do
    get depot_path(depots(:farm), delivery_id: deliveries(:monday_1).id)

    assert_response :success
    assert_select "a[href^='/home_delivery_addresses/']", count: 0
  end

  test "update cannot reassign the member" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])

    patch home_delivery_address_path(overlay), params: {
      home_delivery_address: {
        member_id: members(:john).id,
        name: overlay.name,
        street: overlay.street,
        zip: overlay.zip,
        city: overlay.city,
        delivery_ids: overlay.delivery_ids
      }
    }

    assert_equal members(:bob).id, overlay.reload.member_id
  end

  test "home-delivery depot next list does not link overlay edit without write" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])
    login admins(:external)

    get depot_path(depots(:home), delivery_id: deliveries(:monday_1).id)

    assert_response :success
    assert_select "a[href=?]", edit_home_delivery_address_path(overlay), count: 0
    assert_select ".status-tag", text: /#{Regexp.escape(HomeDeliveryAddress.model_name.human)}/i
  end

  test "destroy redirects to the member" do
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      delivery_ids: [ deliveries(:monday_1).id ])

    assert_difference -> { HomeDeliveryAddress.count }, -1 do
      delete home_delivery_address_path(overlay)
    end
    assert_redirected_to member_path(members(:bob))
  end
end
