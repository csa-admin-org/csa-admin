FactoryBot.define do
  factory :delivery_cycle do
    sequence(:name) { |n| "Cycle #{n}" }
    public_name { "#{name} PUBLIC" }

    basket_size_ids { BasketSize.pluck(:id) }
    depot_ids { Depot.pluck(:id) }

    trait :visible do
      visible { true }
    end
  end
end
