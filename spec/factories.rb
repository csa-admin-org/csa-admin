FactoryGirl.define do
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
    billing_interval  'quarterly'

    validated_at { Time.now }
    validator { create(:admin) }

    created_at { Time.utc(2014) } # no trial by default

    trait :pending do
      validated_at { nil }
      validator { nil }
    end

    trait :waiting do
      waiting_started_at { Time.now }
      waiting_basket { create(:basket) }
      waiting_distribution { create(:distribution) }
    end

    trait :trial do
      created_at { Time.utc(Date.today.year) }
      after :create do |member|
        create(:membership, member: member, started_on: Date.today)
        member.reload
      end
    end

    trait :active do
      after :create do |member|
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
    basket
    distribution
    started_on { Date.today.beginning_of_year }
    ended_on { Date.today.end_of_year }
  end

  factory :basket do
    name { Faker::Name.name }
    year { Date.today.year }
    annual_price { 40 * 30 }
    annual_halfday_works 2
  end

  factory :distribution do
    name { Faker::Name.name }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    zip { Faker::Address.zip }
    basket_price 0
  end

  factory :delivery do
    date { Time.now }
  end

  factory :halfday_work do
    member
    periods { ['am'] }
    date { Date.today.beginning_of_week + 8.days }
    participants_count 1
  end
end
