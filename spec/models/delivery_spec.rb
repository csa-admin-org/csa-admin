# frozen_string_literal: true

require "rails_helper"

describe Delivery do
  it_behaves_like "bulk_dates_insert"

  it "validates bulk inserts" do
    delivery = Delivery.create(
      bulk_dates_starts_on: Date.today,
      bulk_dates_wdays: [ 1 ],
      date: Date.today)

    expect(delivery).not_to have_valid(:bulk_dates_starts_on)
    expect(delivery).not_to have_valid(:bulk_dates_wdays)
  end

  it "bulk inserts with basket_complements", freeze: "2018-01-01" do
    create(:basket_complement, id: 1)

    Delivery.create(
      bulk_dates_starts_on: Date.parse("2018-11-05"),
      bulk_dates_ends_on: Date.parse("2018-11-11") + 1.month,
      bulk_dates_weeks_frequency: 2,
      bulk_dates_wdays: [ 1 ],
      basket_complement_ids: [ 1 ])

    expect(Delivery.count).to eq 3
    expect(Delivery.all.map(&:basket_complement_ids)).to eq [ [ 1 ], [ 1 ], [ 1 ] ]
  end

  it "adds basket_complement on subscribed baskets", freeze: "2022-01-01" do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    create(:delivery)
    perform_enqueued_jobs

    membership_1 = create(:membership, subscribed_basket_complement_ids: [ 1, 2 ])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [ 2 ])
    membership_3 = create(:membership, subscribed_basket_complement_ids: [ 1 ])

    delivery = create(:delivery, basket_complement_ids: [ 1, 2 ])
    perform_enqueued_jobs

    basket1 = delivery.baskets.find_by(membership: membership_1)
    expect(basket1.complement_ids).to match_array [ 1, 2 ]
    expect(basket1.complements_price).to eq 3.2 + 4.5

    basket2 = delivery.baskets.find_by(membership: membership_2)
    expect(basket2.complement_ids).to match_array [ 2 ]
    expect(basket2.complements_price).to eq 4.5

    basket3 = delivery.baskets.find_by(membership: membership_3)
    basket3.update!(complement_ids: [ 1, 2 ])
    expect(basket3.complement_ids).to match_array [ 1, 2 ]
    expect(basket3.complements_price).to eq 3.2 + 4.5
  end

  it "removes basket_complement on subscribed baskets", freeze: "2022-01-01" do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    create(:delivery)
    perform_enqueued_jobs

    membership_1 = create(:membership, subscribed_basket_complement_ids: [ 1, 2 ])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [ 2 ])
    membership_3 = create(:membership, subscribed_basket_complement_ids: [ 1 ])

    delivery = create(:delivery, basket_complement_ids: [ 1, 2 ])
    perform_enqueued_jobs

    basket3 = delivery.baskets.find_by(membership: membership_3)
    basket3.update!(complement_ids: [ 1, 2 ])

    Current.org.update!(recurring_billing_wday: 1)
    membership_1.update!(billing_year_division: 1)
    invoice_1 = Billing::Invoicer.force_invoice!(membership_1.member)
    invoice_1.process!
    invoice_1.mark_as_sent!
    membership_2.update!(billing_year_division: 4)
    invoice_2 = Billing::Invoicer.force_invoice!(membership_2.member)
    invoice_2.process!
    invoice_2.mark_as_sent!

    expect {
      delivery.update!(basket_complement_ids: [ 1 ])
      perform_enqueued_jobs
    }
      .to change { membership_1.reload.price }.by(-4.5)
      .and change { membership_2.reload.price }.by(-4.5)

    basket1 = delivery.baskets.find_by(membership: membership_1)
    expect(basket1.complement_ids).to match_array [ 1 ]
    expect(basket1.complements_price).to eq 3.2

    basket2 = delivery.baskets.find_by(membership: membership_2)
    expect(basket2.complement_ids).to be_empty
    expect(basket2.complements_price).to be_zero

    basket3.reload
    expect(basket3.complement_ids).to match_array [ 1 ]
    expect(basket3.complements_price).to eq 3.2
  end

  it "updated membership price when destroy", freeze: "2022-01-01" do
    basket_size = create(:basket_size, price: 42)
    membership = create(:membership, basket_size: basket_size, deliveries_count: 2)
    delivery = membership.deliveries.last

    expect {
      delivery.destroy!
      perform_enqueued_jobs
    }
      .to change { membership.baskets.count }.by(-1)
      .and change { membership.reload.price }.by(-42)
  end

  it "updates all fiscal year delivery numbers", freeze: "2018-01-01" do
    first = create(:delivery, date: "2018-02-01")
    last = create(:delivery, date: "2018-11-01")

    expect(first.number).to eq 1
    expect(last.number).to eq 2

    delivery = create(:delivery, date: "2018-06-01")

    expect(first.reload.number).to eq 1
    expect(delivery.reload.number).to eq 2
    expect(last.reload.number).to eq 3

    delivery.update!(date: "2018-01-01")

    expect(delivery.reload.number).to eq 1
    expect(first.reload.number).to eq 2
    expect(last.reload.number).to eq 3
  end

  it "handles date change", freeze: "2020-01-01" do
    delivery_1 = create(:delivery, date: "2020-02-01")
    delivery_2 = create(:delivery, date: "2020-04-01")

    membership1 = create(:membership, started_on: "2020-01-01", ended_on: "2020-05-01")
    membership2 = create(:membership, started_on: "2020-03-01", ended_on: "2020-08-01")

    expect {
      delivery_1.update!(date: "2020-06-01")
      perform_enqueued_jobs
    }
      .to change { membership1.reload.baskets.size }.from(2).to(1)
      .and change { membership2.reload.baskets.size }.from(1).to(2)
      .and change { membership1.reload.price }.from(60).to(30)
      .and change { membership2.reload.price }.from(30).to(60)
  end

  specify "handles new delivery change", freeze: "2020-01-01" do
    create(:delivery, date: "2020-02-01")
    create(:delivery, date: "2020-04-01")

    membership1 = create(:membership, started_on: "2020-01-01", ended_on: "2020-05-01")
    membership2 = create(:membership, started_on: "2020-03-01", ended_on: "2020-08-01")

    expect {
      expect {
        create(:delivery, date: "2020-06-01")
        perform_enqueued_jobs
      }
        .to change { membership2.reload.baskets.size }.from(1).to(2)
        .and change { membership2.reload.price }.from(30).to(60)
    }.not_to change { membership1.reload.baskets.size }
  end

  it "flags basket when creating them", freeze: "2020-01-01" do
    create(:delivery, date: "2020-02-01")
    membership = create(:membership, started_on: "2020-01-01", ended_on: "2020-06-01")
    absence = create(:absence,
      member: membership.member,
      started_on: "2020-01-15",
      ended_on: "2020-02-15")

    expect(membership.baskets_count).to eq 1
    expect(membership.baskets.first).to be_absent

    delivery = create(:delivery, date: "2020-02-15")
    perform_enqueued_jobs
    membership.reload

    expect(membership.baskets_count).to eq 2
    expect(membership.baskets.last).to have_attributes(
      state: "absent",
      delivery_id: delivery.id,
      absence: absence)
  end

  specify "reset delivery_cycle cache after date change", freeze: "2023-01-01" do
    cycle = create(:delivery_cycle, wdays: [ 0 ])

    expect { create(:delivery, date: "2023-01-01") }
      .to change { cycle.reload.deliveries_counts }
      .from("2023" => 0, "2024" => 0)
      .to("2023" => 1, "2024" => 0)

    expect { Delivery.last.update!(date: "2023-01-02") }
      .to change { cycle.reload.deliveries_counts }
      .from("2023" => 1, "2024" => 0)
      .to("2023" => 0, "2024" => 0)
  end

  specify "reset delivery_cycle cache after destroy", freeze: "2023-01-01" do
    cycle = create(:delivery_cycle, wdays: [ 0 ])
    delivery = create(:delivery, date: "2023-01-01")

    expect { delivery.destroy! }
      .to change { cycle.reload.deliveries_counts }
      .from("2023" => 1, "2024" => 0)
      .to("2023" => 0, "2024" => 0)
  end

  specify "update baskets after date change", freeze: "2024-01-01" do
    create(:delivery, date: "2024-11-01")
    delivery = create(:delivery, date: "2024-12-01")
    membership = create(:membership, started_on: "2024-01-01", ended_on: "2024-11-30")

    expect {
      perform_enqueued_jobs do
        delivery.update!(date: "2024-11-30")
      end
    }.to change { membership.reload.baskets.size }.from(1).to(2)
  end

  specify "update baskets after destroy", freeze: "2024-01-01" do
    create(:delivery, date: "2024-11-01")
    delivery = create(:delivery, date: "2024-12-01")
    membership = create(:membership)

    expect {
      perform_enqueued_jobs do
        delivery.destroy!
      end
    }.to change { membership.reload.baskets.size }.from(2).to(1)
  end

  describe "#shop_open?" do
    before { create(:depot) }

    specify "when shop_open is false" do
      delivery = create(:delivery, shop_open: false)

      expect(delivery.shop_open?).to eq false
    end

    specify "when shop_open is true and no other restriction" do
      delivery = create(:delivery, shop_open: true)

      expect(delivery.shop_open?).to eq true
    end

    specify "when Organization#shop_delivery_open_delay_in_days is set" do
      Current.org.update!(shop_delivery_open_delay_in_days: 2)

      delivery = travel_to "2021-08-08" do
        create(:delivery, date: "2021-08-10", shop_open: true)
      end

      travel_to "2021-08-08 23:59:59 +02" do
        expect(delivery.shop_open?).to eq true
      end
      travel_to "2021-08-09 00:00:00 +02" do
        expect(delivery.shop_open?).to eq false
      end
    end

    specify "when Organization#shop_delivery_open_last_day_end_time is set" do
      Current.org.update!(shop_delivery_open_last_day_end_time: "12:00")

      delivery = travel_to "2021-08-08" do
        create(:delivery, date: "2021-08-10", shop_open: true)
      end

      travel_to "2021-08-10 12:00:00 +02" do
        expect(delivery.shop_open?).to eq true
      end
      travel_to "2021-08-10 12:00:01 +02" do
        expect(delivery.shop_open?).to eq false
      end
    end

    specify "when both Organization#shop_delivery_open_delay_in_days and Organization#shop_delivery_open_last_day_end_time are set" do
      Current.org.update!(
        shop_delivery_open_delay_in_days: 1,
        shop_delivery_open_last_day_end_time: "12:30")

      delivery = travel_to "2021-08-08" do
        create(:delivery, date: "2021-08-10", shop_open: true)
      end

      travel_to "2021-08-09 12:30:00 +02" do
        expect(delivery.shop_open?).to eq true
      end
      travel_to "2021-08-09 12:30:01 +02" do
        expect(delivery.shop_open?).to eq false
      end
    end
  end
end
