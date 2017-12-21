FactoryBot.define do
  factory :basket_content do
    vegetable
    delivery
    quantity 10
    unit 'kilogramme'
    basket_sizes { BasketContent::SIZES }
    distributions { [create(:distribution)] }
  end

  factory :vegetable do
    name 'Carotte'
  end

  factory :absence do
    member
  end

  factory :admin do
    email { Faker::Internet.email }
    password '12345678'
    password_confirmation '12345678'
  end

  factory :member do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    emails { [Faker::Internet.email, Faker::Internet.email].join(', ') }
    phones { Faker::PhoneNumber.phone_number }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    zip { Faker::Address.zip }
    support_member false
    billing_interval 'quarterly'

    validated_at { Time.zone.now }
    validator { create(:admin) }

    created_at { Time.utc(2014) } # no trial by default

    trait :pending do
      validated_at { nil }
      validator { nil }
    end

    trait :waiting do
      waiting_started_at { Time.zone.now }
      waiting_basket_size { create(:basket_size) }
      waiting_distribution { create(:distribution) }
    end

    trait :trial do
      created_at { Time.utc(Time.zone.today.year) }
      after :create do |member|
        create(:membership, member: member, started_on: Time.zone.today)
        member.reload
      end
    end

    trait :active do
      after :create do |member|
        create(:membership, :last_year, member: member)
        create(:membership, member: member)
        member.reload
      end
    end

    trait :support do
      support_member true
    end

    trait :inactive
  end

  factory :membership do
    member
    basket_size { BasketSize.first || create(:basket_size) }
    distribution
    started_on { Time.zone.today.beginning_of_year }
    ended_on { Time.zone.today.end_of_year }

    trait :last_year do
      started_on { 1.year.ago.beginning_of_year  }
      ended_on { 1.year.ago.end_of_year  }
    end
  end

  factory :basket_size do
    name { Faker::Name.name }
    price 30
    annual_halfday_works 2

    trait :small do
      name 'Eveil'
      price { 925 / 40.0 }
    end

    trait :big do
      name 'Abondance'
      price { 1330 / 40.0 }
    end
  end

  factory :distribution do
    name { Faker::Name.name }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    zip { Faker::Address.zip }
    basket_price 0
  end

  factory :delivery do
    date { Time.zone.now }
  end

  factory :invoice do
    member
    date { Time.zone.now }
    member_billing_interval { member.billing_interval }

    trait :membership do
      transient do
        membership { create(:membership, member: member) }
      end
      memberships_amounts_data {
        [
          membership.slice(:id, :basket_size_id, :distribution_id).merge(
            basket_total_price: membership.basket_total_price,
            basket_description: membership.basket_description,
            distribution_total_price: membership.distribution_total_price,
            distribution_description: membership.distribution_description,
            halfday_works_total_price: membership.halfday_works_total_price,
            halfday_works_description: membership.halfday_works_description,
            description: membership.description,
            price: membership.price
          )
        ]
      }
      memberships_amount_description 'Montant'
    end

    trait :support do
      support_amount Member::SUPPORT_PRICE
    end

    trait :last_year do
      date { 1.year.from_now }
    end

    trait :sent do
      sent_at { Time.zone.now }
    end
  end

  factory :halfday do
    date { Time.zone.today.beginning_of_week + 8.days }
    start_time { Time.zone.parse('8:30') }
    end_time { Time.zone.parse('12:00') }
    place 'Thielle'
    activity 'Aide aux champs'
  end

  factory :halfday_participation do
    member
    halfday
    participants_count 1

    trait :validated do
      validated_at { date }
      validator { create(:admin) }
    end
  end
end
