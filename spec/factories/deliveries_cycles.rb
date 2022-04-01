FactoryBot.define do
  factory :deliveries_cycle do
    sequence(:name) { |n| "Cycle #{n}" }
    public_name { "#{name} PUBLIC" }
  end
end
