FactoryBot.define do
  factory :shop_order, class: Shop::Order do
    member
    delivery
    items_attributes {
      product = create(:shop_product)
      {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        }
      }
    }

    trait :cart do
      state { Shop::Order::CART_STATE }
    end
    trait :pending do
      state { Shop::Order::PENDING_STATE }
    end
  end
end
