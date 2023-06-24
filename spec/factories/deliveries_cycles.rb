FactoryBot.define do
  factory :deliveries_cycle do
    sequence(:name) { |n| "Cycle #{n}" }
    public_name { "#{name} PUBLIC" }

    trait :visible do
      visible { true }
    end
  end
end
