# frozen_string_literal: true

FactoryBot.define do
  factory :newsletter_delivery, class: Newsletter::Delivery do
    newsletter
    member

    trait :processed do
      state { Newsletter::Delivery::PROCESSING_STATE }
      processed_at { Time.current }
    end
  end
end
