# frozen_string_literal: true

FactoryBot.define do
  factory :basket_size do
    sequence(:name) { |n| "Basket Size #{n}" }
    public_name { "#{name} PUBLIC" }
    price { 30 }
    activity_participations_demanded_annually { 2 }

    trait :small do
      name { "Petit" }
      price { 925 / 40.0 }
    end

    trait :medium do
      name { "Moyen" }
      price { 1150 / 40.0 }
    end

    trait :big do
      name { "Grand" }
      price { 1330 / 40.0 }
    end
  end
end
