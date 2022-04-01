FactoryBot.define do
  factory :delivery do
    sequence(:date) { |n| Date.today + n.days }

    after(:create) { |d| d.reload }
  end
end
