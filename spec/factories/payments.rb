FactoryBot.define do
  factory :payment do
    member
    date { Time.current }
    amount { 1000 }

    trait :isr do
      isr_data { 'isr_data' }
    end
  end
end
