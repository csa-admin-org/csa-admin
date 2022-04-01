FactoryBot.define do
  factory :group_buying_product, class: GroupBuying::Product do
    association :producer, factory: :group_buying_producer
    name { 'Farine de Seigle 5 kg (3.15/kg)' }
    price { 15.75 }
  end
end
