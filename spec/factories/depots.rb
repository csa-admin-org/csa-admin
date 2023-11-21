FactoryBot.define do
  factory :depot do
    name { Faker::Address.unique.city }
    public_name { "#{name} PUBLIC" }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    zip { Faker::Address.zip }
    price { 0 }

    delivery_cycles { DeliveryCycle.all || [create(:delivery_cycle)] }
  end
end
