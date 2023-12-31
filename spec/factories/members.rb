FactoryBot.define do
  factory :member do
    name { Faker::Name.unique.name }
    emails { [ Faker::Internet.unique.email, Faker::Internet.unique.email ].join(", ") }
    phones { Faker::Base.unique.numerify("+41 ## ### ## ##") }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    zip { Faker::Address.zip }
    billing_year_division { 4 }
    annual_fee { Current.acp.annual_fee }

    validated_at { Time.current }
    validator { Admin.first || create(:admin) }

    created_at { Time.utc(2014) } # no trial by default

    trait :pending do
      state { "pending" }
      validated_at { nil }
      validator { nil }
      waiting_basket_size { create(:basket_size) }
      waiting_basket_price_extra { 0 }
      waiting_depot { create(:depot) }
    end

    trait :waiting do
      state { "waiting" }
      waiting_started_at { Time.current }
      waiting_basket_size { create(:basket_size) }
      waiting_basket_price_extra { 0 }
      waiting_depot { create(:depot) }
    end

    trait :trial do
      state { "active" }
      created_at { Time.current.beginning_of_year }
      after :create do |member|
        DeliveriesHelper.create_deliveries(1)
        create(:membership,
          member: member,
          started_on: [ Time.current.beginning_of_year, Delivery.last.date - 3.weeks ].max)
      end
    end

    trait :active do
      state { "active" }
      activated_at { Time.current }
      after :create do |member, evaluator|
        unless evaluator.shop_depot
          create(:membership, :last_year, member: member)
          create(:membership, member: member)
        end
      end
    end

    trait :support_annual_fee do
      state { "support" }
      billing_year_division { 1 }
      annual_fee { Current.acp.annual_fee }
    end

    trait :support_acp_share do
      state { "support" }
      billing_year_division { 1 }

      transient do
        acp_shares_number { 1 }
      end

      after :create do |member, evaluator|
        create(:invoice, member: member,
          acp_shares_number: evaluator.acp_shares_number)
      end
    end

    trait :inactive do
      state { "inactive" }
      annual_fee { nil }
    end
  end
end
