# frozen_string_literal: true

require "rails_helper"

describe "Members V1 API" do
  before { integration_session.host = "admin.ragedevert.test" }

  describe "POST /api/v1/members" do
    def request(api_token: nil, params: {})
      api_token ||= Current.org.credentials(:api_token)
      authorization =
        ActionController::HttpAuthentication::Token.encode_credentials(api_token)
      headers = {
        "ACCEPT" => "application/json",
        "HTTP_AUTHORIZATION" => authorization
      }
      post "/api/v1/members", params: params.deep_stringify_keys, headers: headers
    end

    specify "require valid api_token" do
      request(api_token: "not-the-good-one")
      expect(response.status).to eq 401
    end

    specify "create new member and notify admin", sidekiq: :inline do
      admin = create(:admin, notifications: [ "new_inscription" ])

      basket = create(:basket_size, :small)
      depot1 = create(:depot)
      depot2 = create(:depot)
      basket_complement1 = create(:basket_complement)
      basket_complement2 = create(:basket_complement)

      request(params: {
        name: "John Doe",
        emails: "john@doe.com",
        phones: "+41 12 345 67 89",
        country_code: "CH",
        address: "123 Main St",
        zip: "1234",
        city: "La Ville",
        note: "Crée depuis l'API",
        waiting_basket_size_id: basket.id,
        waiting_depot_id: depot1.id,
        waiting_alternative_depot_ids: [ depot2.id ],
        members_basket_complements_attributes: [
          { basket_complement_id: basket_complement1.id, quantity: 1 },
          { basket_complement_id: basket_complement2.id, quantity: 2 }
        ]
      })

      expect(response.status).to eq 201

      member = Member.last
      expect(member).to have_attributes(
        name: "John Doe",
        emails: "john@doe.com",
        phones: "+41123456789",
        country_code: "CH",
        address: "123 Main St",
        zip: "1234",
        city: "La Ville",
        note: "Crée depuis l'API",
        waiting_basket_size_id: basket.id,
        waiting_depot_id: depot1.id,
        waiting_delivery_cycle_id: 1)
      expect(member.waiting_alternative_depot_ids).to eq [ depot2.id ]
      expect(member.members_basket_complements.first).to have_attributes(
        basket_complement_id: basket_complement1.id,
        quantity: 1)
      expect(member.members_basket_complements.second).to have_attributes(
        basket_complement_id: basket_complement2.id,
        quantity: 2)


      expect(AdminMailer.deliveries.size).to eq 1
      mail = AdminMailer.deliveries.last
      expect(mail.subject).to eq "Nouvelle inscription"
      expect(mail.to).to eq [ admin.email ]
      expect(mail.body.encoded).to include admin.name
      expect(mail.body.encoded).to include "John Doe"
    end
  end
end
