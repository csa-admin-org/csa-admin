FactoryBot.define do
  factory :depot do
    name { Faker::Address.unique.city }
    public_name { "#{name} PUBLIC" }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    zip { Faker::Address.zip }
    price { 0 }

    deliveries_cycles { [DeliveriesCycle.first || create(:deliveries_cycle)] }
  end
end
