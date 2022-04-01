FactoryBot.define do
  factory :shop_producer, class: Shop::Producer do
    name { 'la ferme à mathurin' }
    website_url { 'https://lafermeamathurin.com' }
  end
end
