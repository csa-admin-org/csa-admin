FactoryBot.define do
  factory :group_buying_order, class: GroupBuying::Order do
    member
    association :delivery, factory: :group_buying_delivery
    terms_of_service { '1' }
    items_attributes { {
      '0' => {
        product_id: create(:group_buying_product).id,
        quantity: 1
      }
    } }
  end
end
