require "rails_helper"

describe Shop::SpecialDelivery do
  specify "#update_shop_products_count" do
    product1 = create(:shop_product)
    product2 = create(:shop_product)
    product3 = create(:shop_product)

    delivery = create(:shop_special_delivery, products: [ product1, product2 ])
    expect(delivery.shop_products_count).to eq(2)

    delivery.products << product3
    delivery.save!
    expect(delivery.shop_products_count).to eq(3)
  end

  specify "#shop_closing_at" do
    delivery = build(:shop_special_delivery,
      open: false,
      date: "2022-12-10",
      open_delay_in_days: nil,
      open_last_day_end_time: nil)

    expect(delivery.shop_closing_at).to be_nil
    expect(delivery.shop_open?).to eq false

    delivery.open = true
    expect(delivery.shop_closing_at).to eq Time.zone.parse("2022-12-10 23:59:59")

    delivery.open_delay_in_days = 5
    expect(delivery.shop_closing_at).to eq Time.zone.parse("2022-12-05 23:59:59")

    delivery.open_last_day_end_time = "12:00:00"
    expect(delivery.shop_closing_at).to eq Time.zone.parse("2022-12-05 12:00:00")

    travel_to Time.zone.parse("2022-12-05 12:00:00") do
      expect(delivery.shop_open?).to eq true
    end
    travel_to Time.zone.parse("2022-12-05 12:00:01") do
      expect(delivery.shop_open?).to eq false
    end
  end
end
