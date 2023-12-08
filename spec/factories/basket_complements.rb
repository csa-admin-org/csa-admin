FactoryBot.define do
  factory :basket_complement do
    sequence(:name) { |n| "Basket Complement #{n}" }
    public_name { "#{name} PUBLIC" }
    price { 4.2 }
    delivery_ids { Delivery.pluck(:id) }
  end
end
