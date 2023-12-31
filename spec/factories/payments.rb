FactoryBot.define do
  factory :payment do
    member
    date { Time.current }
    amount { 1000 }

    trait :qr do
      fingerprint { "fingerprint" }
    end
  end
end
