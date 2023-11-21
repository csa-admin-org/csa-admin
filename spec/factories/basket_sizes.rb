FactoryBot.define do
  factory :basket_size do
    sequence(:name) { |n| "Basket Size #{n}" }
    public_name { "#{name} PUBLIC" }
    price { 30 }
    activity_participations_demanded_annualy { 2 }

    trait :small do
      name { 'Eveil' }
      price { 925 / 40.0 }
    end

    trait :big do
      name { 'Abondance' }
      price { 1330 / 40.0 }
    end
  end
end
