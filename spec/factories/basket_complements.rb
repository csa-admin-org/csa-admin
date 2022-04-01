FactoryBot.define do
  factory :basket_complement do
    sequence(:name) { |n| "Basket Complement #{n}" }
    public_name { "#{name} PUBLIC" }
    price { 4.2 }
    delivery_ids { Delivery.pluck(:id) }

    trait :annual_price_type do
      price_type { 'annual' }
      price { 200 }
    end
  end
end
