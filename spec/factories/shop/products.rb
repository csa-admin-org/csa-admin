FactoryBot.define do
  factory :shop_product, class: Shop::Product do
    association :producer, factory: :shop_producer
    name { 'Farine de Seigle' }
    variants_attributes { {
      '0' => {
        name: '5 kg',
        price: 16.75
      },
      '1' => {
        name: '10 kg',
        price: 30.5
      }
    } }
  end
end
