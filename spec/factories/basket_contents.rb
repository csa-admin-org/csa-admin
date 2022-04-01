FactoryBot.define do
  factory :basket_content do
    vegetable
    delivery { Delivery.first || create(:delivery) }
    quantity { 10 }
    unit { 'kg' }
    depots { [Depot.first || create(:depot)] }
  end
end
