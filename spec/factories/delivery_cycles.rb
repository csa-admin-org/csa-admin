FactoryBot.define do
  factory :delivery_cycle do
    sequence(:name) { |n| "Cycle #{n}" }
    public_name { "#{name} PUBLIC" }

    depots { Depot.all }
  end
end
