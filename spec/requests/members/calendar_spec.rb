# frozen_string_literal: true

require "rails_helper"

describe "Calendar feed" do
  before { integration_session.host = "members.acme.test" }

  specify "without token" do
    get "/calendar.ics"
    expect(response.status).to eq 401
  end

  specify "with a wrong token" do
    get "/calendar.ics", params: { token: "wrong" }
    expect(response.status).to eq 401
  end

  describe "with a good token" do
    let(:member) { create(:member) }

    def request
      get "/calendar.ics", params: { token: member.generate_token_for(:calendar) }
      response.body.split("\r\n")
    end

    specify "empty" do
      lines = request

      expect(response.status).to eq 200
      expect(response.headers["Content-Type"]).to eq "text/calendar; charset=utf-8"

      expect(lines).to include "NAME:Calendrier Rage de Vert"
      expect(lines).to include "X-WR-CALNAME:Calendrier Rage de Vert"
      expect(lines).to include "URL;VALUE=URI:https://membres.acme.test"
      expect(lines).to include "COLOR:#19A24A"
      expect(lines).to include "X-APPLE-CALENDAR-COLOR:#19A24A"
    end

    describe "with basket", freeze: "2024-01-01" do
      before { create(:delivery, date: "2024-11-01") }
      let(:depot) { create(:depot, name: "Dépôt du coin",
        address: "1 rue du coin", city: "La Chaux-de-Fonds", zip: "2300") }
      let(:basket_size) { create(:basket_size, public_name: "Grand") }

      specify "with trial basket" do
        Current.org.update!(trial_baskets_count: 1)
        create(:membership, member: member, depot: depot, basket_size: basket_size)

        lines = request

        expect(lines).to include "SUMMARY:Panier Rage de Vert (essai)"
        expect(lines).to include "DTSTART;VALUE=DATE:20241101"
        expect(lines).to include "DTEND;VALUE=DATE:20241101"
        expect(lines).to include "CLASS:PRIVATE"
        expect(lines).to include "LOCATION:1 rue du coin\\, 2300 La Chaux-de-Fonds"
        expect(lines).to include "DESCRIPTION:Panier: Grand\\nDépôt: Dépôt du coin"
      end

      specify "with absent basket" do
        Current.org.update!(trial_baskets_count: 1)
        create(:membership, member: member)
        create(:absence, member: member,
          started_on: "2024-11-01",
          ended_on: "2024-11-07")

        lines = request

        expect(lines).to include "SUMMARY:Panier Rage de Vert (absent)"
        expect(lines).to include "DTSTART;VALUE=DATE:20241101"
        expect(lines).to include "DTEND;VALUE=DATE:20241101"
      end

      specify "with basket complement" do
        Current.org.update!(trial_baskets_count: 0)
        depot.update!(name: "Ferme")
        complement_1 = create(:basket_complement, public_name: "Pain")
        complement_2 = create(:basket_complement, public_name: "Fromage")
        create(:membership, member: member, depot: depot, basket_size: basket_size,
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: complement_1.id, quantity: 2 },
          "1" => { basket_complement_id: complement_2.id, quantity: 1 }
        })

        lines = request

        expect(lines).to include "SUMMARY:Panier Rage de Vert"
        expect(lines).to include "DTSTART;VALUE=DATE:20241101"
        expect(lines).to include "DTEND;VALUE=DATE:20241101"
        expect(lines).to include "DESCRIPTION:Panier: Grand\\nCompléments: 2x Pain et Fromage\\nDépôt: Ferme"
      end
    end

    describe "with activity participation", freeze: "2024-01-01" do
      let(:activity) { create(:activity,
        date: "2024-11-01",
        place: "Ferme",
        place_url: "https://ferme.ch",
        title: "Aide dans les champs",
        start_time: "08:30",
        end_time: "12:00",
        description: "Aidez-nous à récolter!")
      }
      let(:activity_2) { create(:activity,
        date: "2024-11-01",
        place: "Ferme",
        place_url: "https://ferme.ch",
        title: "Aide dans les champs",
        start_time: "13:30",
        end_time: "17:00",
        description: "Aidez-nous à récolter!")
      }

      specify "with future activity participation" do
        create(:activity_participation,
          member: member,
          activity: activity,
          participants_count: 2)

        lines = request

        expect(lines).to include "SUMMARY:Aide dans les champs (Rage de Vert)"
        expect(lines).to include "DTSTART;TZID=Europe/Zurich:20241101T083000"
        expect(lines).to include "DTEND;TZID=Europe/Zurich:20241101T120000"
        expect(lines).to include "URL;VALUE=URI:https://ferme.ch"
        expect(lines).to include "LOCATION:Ferme"
        expect(lines).to include "CLASS:PRIVATE"
        expect(lines).to include(
          "DESCRIPTION:Participants: 2\\n\\nAidez-nous à récolter!\\n\\nhttp://members.a",
          " cme.test/activity_participations")
      end

      specify "with future activity participation (all day)" do
        create(:activity_participation,
          member: member,
          activity: activity,
          participants_count: 2)
        create(:activity_participation,
          member: member,
          activity: activity_2,
          participants_count: 2)

        lines = request

        expect(lines).to include "SUMMARY:Aide dans les champs (Rage de Vert)"
        expect(lines).to include "DTSTART;TZID=Europe/Zurich:20241101T083000"
        expect(lines).to include "DTEND;TZID=Europe/Zurich:20241101T170000"
      end

      specify "with carpooling" do
        create(:activity_participation,
          member: member,
          activity: activity,
          participants_count: 2)

        create(:activity_participation, :carpooling,
          activity: activity,
          carpooling_phone: "079 123 45 67",
          carpooling_city: "Thielle")
        create(:activity_participation, :carpooling,
          activity: activity,
          carpooling_phone: "079 765 43 21",
          carpooling_city: "La Chaux-de-Fonds")

        lines = request

        expect(lines).to include "SUMMARY:Aide dans les champs (Rage de Vert)"
        expect(lines).to include(
          "DESCRIPTION:Participants: 2\\n\\nAidez-nous à récolter!\\n\\nCovoiturage:\\n- ",
          " +41 79 123 45 67 (Thielle)\\n- +41 79 765 43 21 (La Chaux-de-Fonds)\\n\\nhttp",
          " ://members.acme.test/activity_participations")
      end

      specify "with rejected activity participation" do
        create(:activity_participation, :rejected, member: member, activity: activity)

        lines = request

        expect(lines).to include "SUMMARY:Aide dans les champs (Rage de Vert) ❌"
      end

      specify "with validated activity participation" do
        create(:activity_participation, :validated, member: member, activity: activity)

        lines = request

        expect(lines).to include "SUMMARY:Aide dans les champs (Rage de Vert) ✅"
      end
    end
  end
end
