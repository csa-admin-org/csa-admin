FactoryBot.define do
  factory :activity_participation do
    member
    activity
    participants_count { 1 }
    state { "pending" }

    trait :carpooling do
      carpooling { "1" }
      carpooling_phone { Faker::Base.numerify("+41 ## ### ## ##") }
      carpooling_city { Faker::Address.city }
    end

    trait :validated do
      activity { create(:activity, date: 1.day.ago) }
      state { "validated" }
      validated_at { Time.current }
      validator { create(:admin) }
    end

    trait :rejected do
      activity { create(:activity, date: 1.day.ago) }
      state { "rejected" }
      rejected_at { Time.current }
      validator { create(:admin) }
    end
  end
end
