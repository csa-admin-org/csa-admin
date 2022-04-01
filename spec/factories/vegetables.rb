FactoryBot.define do
  factory :vegetable do
    name { Faker::Food.unique.vegetables }
  end
end
