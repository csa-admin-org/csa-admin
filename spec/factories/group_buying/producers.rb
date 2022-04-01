FactoryBot.define do
  factory :group_buying_producer, class: GroupBuying::Producer do
    name { 'la ferme à mathurin' }
    website_url { 'https://lafermeamathurin.com' }
  end
end
