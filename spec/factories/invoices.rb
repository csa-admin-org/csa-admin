# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    member
    date { Time.current }
    sent_at { Time.current }

    trait :membership do
      entity { create(:membership, member: member, deliveries_count: 4) }
      memberships_amount_description { "Montant" }
    end

    trait :annual_fee do
      entity_type { "AnnualFee" }
      annual_fee { member.annual_fee }
    end

    trait :share do
      entity_type { "Share" }
      shares_number { 1 }
    end

    trait :activity_participation do
      missing_activity_participations_count { 1 }
      missing_activity_participations_fiscal_year { Current.fiscal_year.year }
      activity_price { Current.org.activity_price }
    end

    trait :manual do
      transient do
        item_price { nil }
      end

      entity_type { "" }
      after(:build) do |invoice, evaluator|
        if evaluator.item_price
          invoice.items_attributes = {
            "0" => { description: "Un truc", amount: evaluator.item_price }
          }
        end
      end
    end

    trait :processing do
      state { "processing" }
      sent_at { nil }
    end

    trait :not_sent do
      sent_at { nil }
    end

    trait :open do
      state { "open" }
    end

    trait :closed do
      state { "closed" }
    end

    trait :canceled do
      state { "canceled" }
      canceled_at { Time.current }
    end
  end
end
