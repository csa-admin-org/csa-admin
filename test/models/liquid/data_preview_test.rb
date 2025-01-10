# frozen_string_literal: true

require "test_helper"

class Liquid::DataPreviewTest < ActiveSupport::TestCase
  test "recursively render drop data" do
    travel_to "2024-01-01"
    mail_template = mail_templates(:member_activated)
    data = Liquid::DataPreview.for(mail_template, random: 1)

    assert_equal({
      "basket" => {
        "complements" => [],
        "complements_description" => nil,
        "contents" => [],
        "delivery" => {
          "date" => "1 April 2024"
        },
        "depot" => {
          "id" => depots(:home).id,
          "member_note" => nil,
          "name" => "Home"
        },
        "description" => "Small basket",
        "quantity" => 1,
        "size" => {
          "id" => basket_sizes(:small).id,
          "name" => "Small basket"
        }
      },
      "member" =>  {
        "activities_url" => "https://members.acme.test/activity_participations",
        "annual_fee" => "CHF 30.00",
        "balance" => "CHF 0.00",
        "billing_email" => false,
        "billing_url" => "https://members.acme.test/billing",
        "membership_renewal_url" => "https://members.acme.test/memberships#renewal",
        "name" => "John Doe",
        "page_url" => "https://members.acme.test",
        "shop_depot" => nil
      },
      "membership" => {
        "activity_participations_accepted_count" => 2,
        "activity_participations_demanded_count" => 2,
        "activity_participations_missing_count" => 0,
        "basket_complement_names" => "Bread and Eggs",
        "basket_complements" => [
          {
            "description" => "Eggs",
            "id" => basket_complements(:eggs).id,
            "name" => "Eggs",
            "quantity" => 1
          },
          {
            "description" => "Bread",
            "id" => basket_complements(:bread).id,
            "name" => "Bread",
            "quantity" => 1
          }
        ],
        "basket_complements_description" => "Bread and Eggs",
        "basket_quantity" => 1,
        "basket_size" => {
          "id" => basket_sizes(:medium).id,
          "name" => "Medium basket"
        },
        "depot" => {
          "id" => depots(:home).id,
          "member_note" => nil,
          "name" => "Home"
        },
        "delivery_cycle" => {
          "id" => 1,
          "name" => "Mondays"
        },
        "end_date" => "31 December 2024",
        "first_delivery" => {
          "date" => "1 April 2024"
        },
        "last_delivery" => {
          "date" => "6 June 2024"
        },
        "renewal_state" => "renewal_pending",
        "start_date" => "1 January 2024",
        "state" => "ongoing",
        "trial_baskets_count" => 2
      },
      "organization" => {
        "activity_phone" => nil,
        "email" => "info@acme.test",
        "name"=> "Acme",
        "phone"=> "+41 76 449 59 38",
        "url" => "https://www.acme.test"
      }
    }, data)
  end

  test "render non-drop data" do
    mail_template = mail_templates(:member_validated)
    data = Liquid::DataPreview.for(mail_template, random: 1)

    assert_equal({
      "member" =>  {
        "activities_url" => "https://members.acme.test/activity_participations",
        "annual_fee" => "CHF 30.00",
        "balance" => "CHF 0.00",
        "billing_email" => false,
        "billing_url" => "https://members.acme.test/billing",
        "membership_renewal_url" => "https://members.acme.test/memberships#renewal",
        "name" => "John Doe",
        "page_url" => "https://members.acme.test",
        "shop_depot" => nil
      },
      "organization" => {
        "activity_phone" => nil,
        "email" => "info@acme.test",
        "name"=> "Acme",
        "phone"=> "+41 76 449 59 38",
        "url" => "https://www.acme.test"
      },
      "waiting_list_position" => 2,
      "waiting_basket_size_id" => basket_sizes(:medium).id,
      "waiting_basket_size" => {
        "id" => basket_sizes(:medium).id,
        "name" => "Medium basket"
      },
      "waiting_depot" => {
        "id" => depots(:farm).id,
        "member_note" => nil,
        "name" => "Our farm"
      },
      "waiting_depot_id" => depots(:farm).id
    }, data)
  end

  test "without any feature" do
    travel_to "2024-01-01"
    Current.org.update_column(:features, [])
    mail_template = mail_templates(:member_activated)
    data = Liquid::DataPreview.for(mail_template, random: 1)

    assert_equal({
      "basket" => {
        "complements" => [],
        "complements_description" => nil,
        "delivery" => {
          "date" => "1 April 2024"
        },
        "depot" => {
          "id" => depots(:home).id,
          "member_note" => nil,
          "name" => "Home"
        },
        "description" => "Small basket",
        "quantity" => 1,
        "size" => {
          "id" => basket_sizes(:small).id,
          "name" => "Small basket"
        }
      },
      "member" =>  {
        "annual_fee" => "CHF 30.00",
        "balance" => "CHF 0.00",
        "billing_email" => false,
        "billing_url" => "https://members.acme.test/billing",
        "membership_renewal_url" => "https://members.acme.test/memberships#renewal",
        "name" => "John Doe",
        "page_url" => "https://members.acme.test"
      },
      "membership" => {
        "basket_complement_names" => "Bread and Eggs",
        "basket_complements" => [
          {
            "description" => "Eggs",
            "id" => basket_complements(:eggs).id,
            "name" => "Eggs",
            "quantity" => 1
          },
          {
            "description" => "Bread",
            "id" => basket_complements(:bread).id,
            "name" => "Bread",
            "quantity" => 1
          }
        ],
        "basket_complements_description" => "Bread and Eggs",
        "basket_quantity" => 1,
        "basket_size" => {
          "id" => basket_sizes(:medium).id,
          "name" => "Medium basket"
        },
        "depot" => {
          "id" => depots(:home).id,
          "member_note" => nil,
          "name" => "Home"
        },
        "delivery_cycle" => {
          "id" => 1,
          "name" => "Mondays"
        },
        "end_date" => "31 December 2024",
        "first_delivery" => {
          "date" => "1 April 2024"
        },
        "last_delivery" => {
          "date" => "6 June 2024"
        },
        "renewal_state" => "renewal_pending",
        "start_date" => "1 January 2024",
        "state" => "ongoing",
        "trial_baskets_count" => 2
      },
      "organization" => {
        "email" => "info@acme.test",
        "name"=> "Acme",
        "phone"=> "+41 76 449 59 38",
        "url" => "https://www.acme.test"
      }
    }, data)
  end
end
