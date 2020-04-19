require 'rails_helper'

describe Depot do
  describe '#deliveries_count' do
    it 'counts future deliveries when exits' do
      depot = create(:depot, deliveries_count: 2)
      create(:delivery,
        date: 1.year.from_now,
        depot_ids: [depot.id])

      expect(depot.deliveries_count).to eq 1
    end
  end

  it 'adds baskets when a delivery is added' do
    depot = create(:depot, deliveries_count: 3)
    delivery1 = depot.deliveries[0]
    delivery2 = depot.deliveries[1]
    delivery3 = depot.deliveries[2]
    depot.update!(delivery_ids: [delivery1.id, delivery3.id])

    membership1 = create(:membership, depot: depot)
    membership2 = create(:membership, depot: depot)

    expect(membership1.deliveries).to eq [delivery1, delivery3]
    expect(membership2.deliveries).to eq membership1.deliveries

    expect {
      depot.update!(current_delivery_ids: [delivery1.id, delivery2.id, delivery3.id])
    }.to change { Basket.count }.by(2)

    expect(membership1.reload.deliveries).to eq [delivery1, delivery2, delivery3]
    expect(membership2.reload.deliveries).to eq membership1.deliveries

    expect(membership1.baskets[1].delivery).to eq delivery2
    expect(membership2.baskets[1].delivery).to eq delivery2
  end

  it 'removes baskets when a delivery is removed' do
    depot = create(:depot, deliveries_count: 3)
    delivery1 = depot.deliveries[0]
    delivery2 = depot.deliveries[1]
    delivery3 = depot.deliveries[2]
    membership1 = create(:membership, depot: depot)
    membership2 = create(:membership, depot: depot)

    expect(membership1.deliveries).to eq [delivery1, delivery2, delivery3]
    expect(membership2.deliveries).to eq membership1.deliveries

    expect { depot.update!(current_delivery_ids: [delivery1.id, delivery3.id]) }
      .to change { Basket.count }.by(-2)
      .and change { membership1.reload.price }.from(90).to(60)

    expect(membership1.reload.deliveries).to eq [delivery1, delivery3]
    expect(membership2.reload.deliveries).to eq membership1.deliveries
  end
end
