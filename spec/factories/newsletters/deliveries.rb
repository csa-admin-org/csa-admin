FactoryBot.define do
  factory :newsletter_delivery, class: Newsletter::Delivery do
    newsletter
    member

    trait :processed do
      state { Newsletter::Delivery::PENDING_STATE }
      processed_at { Time.current }
    end
  end
end
