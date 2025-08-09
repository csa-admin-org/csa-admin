# frozen_string_literal: true

require "test_helper"

class API::V1::MembersControllerTest < ActionDispatch::IntegrationTest
  def request(params: {}, api_token: nil)
    api_token ||= Current.org.api_token
    authorization = ActionController::HttpAuthentication::Token.encode_credentials(api_token)
    headers = {
      "ACCEPT" => "application/json",
      "AUTHORIZATION" => authorization
    }
    host! "admin.acme.test"
    post "/api/v1/members", headers: headers, params: params
  end

  test "requires valid api_token" do
    request(api_token: "not-the-good-one")
    assert_response :unauthorized
  end

  test "creates a new member" do
    admins(:master).update_column(:notifications, %w[ new_registration ])

    params = {
      name: "John Woo",
      address: "123 Main St",
      zip: "12345",
      city: "Anytown",
      country_code: "CH",
      emails: "john@woo.com",
      phones: "+41 12 345 67 89",
      waiting_basket_size_id: small_id,
      waiting_depot_id: depots(:bakery).id,
      members_basket_complements_attributes: [
        { basket_complement_id: bread_id, quantity: 1 },
        { basket_complement_id: eggs_id, quantity: 2 }
      ]
    }

    assert_difference("Member.count") do
      request(params: params)
      perform_enqueued_jobs
    end

    assert_response :created

    member = Member.last
    assert_equal "John Woo", member.name
    assert_equal "123 Main St", member.address
    assert_equal "12345", member.zip
    assert_equal "Anytown", member.city
    assert_equal "CH", member.country_code
    assert_equal "john@woo.com", member.emails
    assert_equal "+41123456789", member.phones
    assert_equal basket_sizes(:small), member.waiting_basket_size
    assert_equal depots(:bakery), member.waiting_depot
    assert_equal 2, member.members_basket_complements.size

    assert_equal 1, AdminMailer.deliveries.size
    mail = AdminMailer.deliveries.last
    assert_equal "New registration", mail.subject
    assert_equal [ admins(:master).email ], mail.to
    assert_includes mail.html_part.body.to_s, "John Woo"
  end

  test "returns unprocessable entity for invalid member" do
    params = { name: "" }

    assert_no_difference("Member.count") do
      request(params: params)
    end

    assert_response :unprocessable_entity
  end
end
