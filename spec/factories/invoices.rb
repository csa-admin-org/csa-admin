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

    trait :activity_participation do
      paid_missing_activity_participations { 1 }
      activity_price { Current.acp.activity_price }
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

    trait :unprocessed do
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
