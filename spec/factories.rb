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
    name 'Bob'
    email { Faker::Internet.email }
    rights 'superadmin'
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
      state Member::PENDING_STATE
      validated_at { nil }
      validator { nil }
    end

    trait :waiting do
      state Member::WAITING_STATE
      waiting_started_at { Time.zone.now }
      waiting_basket_size { create(:basket_size) }
      waiting_distribution { create(:distribution) }
    end

    trait :trial do
      created_at { Time.current.beginning_of_year }
      after :create do |member|
        create(:membership,
          member: member,
          started_on: [Time.current.beginning_of_year, Time.zone.today - 3.weeks].max)
        member.reload
        member.update_state!
      end
    end

    trait :active do
      after :create do |member|
        create(:membership, :last_year, member: member)
        create(:membership, member: member)
        member.reload
        member.update_state!
      end
    end

    trait :support do
      support_member true
    end

    trait :inactive do
      state Member::INACTIVE_STATE
    end
  end

  factory :membership do
    member
    basket_size_id { BasketSize.first&.id || create(:basket_size).id }
    distribution_id { Distribution.first&.id || create(:distribution).id }
    started_on { Time.zone.today.beginning_of_year }
    ended_on { Time.zone.today.end_of_year }

    trait :last_year do
      started_on { 1.year.ago.beginning_of_year  }
      ended_on { 1.year.ago.end_of_year  }
    end

    # Clear memory attributes
    after :create do |membership|
      membership.basket_size_id = nil
      membership.distribution_id = nil
    end
  end

  factory :basket do
    membership
    delivery
    basket_size
    distribution
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
    price 0
  end

  factory :delivery do
    date { Time.zone.now }
  end

  factory :invoice do
    member
    date { Time.current }
    member_billing_interval { member.billing_interval }

    trait :membership do
      membership { create(:membership, member: member) }
      memberships_amount_description 'Montant'
    end

    trait :support do
      support_amount Member::SUPPORT_PRICE
    end

    trait :last_year do
      date { 1.year.from_now }
    end

    trait :not_sent do
      state 'not_sent'
      sent_at nil
    end

    trait :open do
      state 'open'
      sent_at { Time.current }
    end

    trait :canceled do
      state 'canceled'
      canceled_at { Time.current }
    end
  end

  factory :payment do
    member
    date { Time.current }
    amount 1000
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
